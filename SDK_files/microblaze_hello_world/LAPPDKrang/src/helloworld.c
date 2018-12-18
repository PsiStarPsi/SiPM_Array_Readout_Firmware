/*
 * lappd_os.c
 * Copyright(c) 2018 Kevin Croker, Kurtis Nishimura
 *
 * Adapted code from Samuel Jacob (samueldotj@gmail.com) (dhcp-client simple)
 *
 */

// Includes for ublaze
//#include <stdio.h>
#include "platform.h"
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <malloc.h>
#include <string.h>
/* Lets see which ones of these actually work */
#include "xparameters.h"
#include "mb_interface.h"
#include "fsl.h"
#include "xil_types.h"
#include "xil_io.h"

#include "lappd_os.h"
#include "lappd_regmap.h"

// Use convention where macros are uppercase
// Notice critical proliferation of parenthesis
#define NISHI_REG_READ(into, where) ((into) = *( (u32 *)(XPAR_IOMODULE_0_IO_BASEADDR | (where))) );
#define NISHI_REG_WRITE(where, what) ( *( (u32 *)(XPAR_IOMODULE_0_IO_BASEADDR | (where))) = (what) );

// From: ethMain.c

// Buffers for input data
u8 *gInboundData;
struct EthFrame *gInboundFrame;

// Variables for tracking incoming data buffer positions and status
u32 gInboundWordPos = 0;
u32 gCompletePacket = 0;
u32 *gpInboundFrame;

// Now some internal structures I use for keeping track of myself

struct NIFT_ip NIFT_ipsystem;
struct NIFT_lappd lappd;

void resetFrame(void) {
  gInboundWordPos = 0;
  gCompletePacket = 0;
  memset((void *) gInboundData, 0, MAX_PACKET_SIZE);
  gpInboundFrame = (u32 *) gInboundData;
}

// Hax to place the ethernet payload itself on a 4-byte alignment
#define HAX 2

void initMemory() {

  gInboundData = (u8 *) memalign(4, MAX_PACKET_SIZE + HAX);
  if(!gInboundData)
    exit(2);
  
  // KC 9/13/18 - why are we advancing 2 pointer widths?
  // A: Because the ethernet PAYLOAD must sit on a 4-byte aligned boundary
  //    or else everything else is fucked.
  //
  gInboundData += HAX;
  gInboundFrame = (struct EthFrame *) gInboundData;
  resetFrame();
}

// KC 10/18/18: completely mysterious black box functions...
void clearLast() {
	u32 msrData = mfmsr();
	msrData &= ~0x10;
	mtmsr(msrData);
}

// Reads a single word off of a given channel
// KC 10/18/18: changed to a single channel for now.
// later, abstract this.
void readFsl(void) {

  u32 tempInvalid = 0;
  u32 tempLast = 0;
  u32 tempData = 0;
  //The standard bogus workaround until we figure out how
  //to get getdfslx to work.

  getfslx(tempData, 0, FSL_NONBLOCKING);

  // KC: guess this is checking for error conditionsa
  fsl_isinvalid(tempInvalid);
  fsl_iserror(tempLast);
  
  // Copy the data and update the word position if data was good
  if (!tempInvalid) {
    memcpy(gpInboundFrame, &tempData, 4);

    // XXX this will overflow
    if (gInboundWordPos < MAX_PACKET_SIZE / 4) {
      ++gInboundWordPos; //++;
      ++gpInboundFrame; //++;
    }
  }
  
  // Update the last flag
  if (tempLast) {
    gCompletePacket = 1;
    clearLast();
  }
}

void sendFrame(u8 *frame, u32 byteSize) {

  u32 defaultWords;
  u32 finalWord = 0;
  u8 residue;
  
  defaultWords = (byteSize >> 2);
  residue = (u8)(byteSize - (defaultWords << 2));
  
  if(!residue) {
    --defaultWords;
    memcpy(&finalWord, frame + byteSize - 4, 4);
  }
  else
    memcpy(&finalWord, frame + byteSize - 4, residue);

  // Put all the default words
  // Recycle: byteSize
  u32 tmp = 0;
  while(tmp < defaultWords) {

    memcpy(&byteSize, frame + tmp * 4, 4);
    putfslx(byteSize, 0, FSL_DEFAULT);
    ++tmp;
  }

  // Now put the final word
  putfslx(finalWord, 0, FSL_CONTROL);
}

/// End Kurtis/Croker FSL routines

/// My routines

// This will block until a frame is read.
void NIFT_intakeFrame(void) {

  // This loads a frame
  while(!gCompletePacket)
    readFsl();
}


static int get_mac_address(u8 *mac) {

  u32 derp = 0;

  NISHI_REG_READ(derp, INTERNAL_OFFSET | REG_INTERNAL_DNA_LOW);
  memcpy(mac, &derp, 2);

  NISHI_REG_READ(derp, INTERNAL_OFFSET | REG_INTERNAL_DNA_HIGH);
  memcpy(mac + 2, &derp, 4);

  // XXX Check for IOModule failures...
  return 0;
}

/*
 * Return checksum for the given data.
 * Copied from FreeBSD
 */
static unsigned short in_cksum(unsigned short *addr, int len)
{
    register int sum = 0;
    u_short answer = 0;
    register u_short *w = addr;
    register int nleft = len;
    /*
     * Our algorithm is simple, using a 32 bit accumulator (sum), we add
     * sequential 16 bit words to it, and at the end, fold back all the
     * carry bits from the top 16 bits into the lower 16 bits.
     */
    while (nleft > 1)
    {
        sum += *w++;
        nleft -= 2;
    }
    /* mop up an odd byte, if necessary */
    if (nleft == 1)
    {
        *(u_char *)(&answer) = *(u_char *) w;
        sum += answer;
    }
    /* add back carry outs from top 16 bits to low 16 bits */
    sum = (sum >> 16) + (sum & 0xffff);     /* add hi 16 to low 16 */
    sum += (sum >> 16);             /* add carry */
    answer = ~sum;              /* truncate to 16 bits */
    return (answer);
}


/*
 * This function will be called for any incoming DHCP responses
 */
static void dhcp_input(dhcp_t *dhcp) {

  u8 *ptr;
  u16 N;
  
  // There could be something else making DHCP requests...
  // Do we care about offers?  Remember these were vectored directly at our MAC
  // and if we got this far (we're not promiscous), so this shit was directed to us.
  if (! (dhcp->opcode == DHCP_OPTION_OFFER))
    return;

  if(!NIFT_ipsystem.configured) {
    
    // Immediately grab the IP address (this is set from the BOOTP and is not technically DHCP)
    NIFT_ipsystem.ip = Xil_Ntohl(dhcp->yiaddr);

    // Seems like my dhcp server is not setting the siaddr correctly in the BOOTP packet
    // extremely annoying.
    //    NIFT_ipsystem.dhcpserver = Xil_Ntohl(dhcp->siaddr);
  }

  // XXX: Assume that the DHCP-kine indicator is the first thing in the pocket...
  // Try to parse the messages to see what we are doing
  ptr = dhcp->bp_options;

  // Tag check
  if(*ptr != MESSAGE_TYPE_DHCP) {

    // Something is fucked, deconfigure and try again
    NIFT_ipsystem.configured = 0;
    return;
  }

  // How's that for some brainfuck C?
  // increment the incremented pointer by the value it had before did this
  // This is because ++ptr is apparently always a length field

  // On the main tag.
  N = *(++ptr);
  ++ptr;

  // (This should be essentially += 2.)
  
  // Now we're on the main tag's data: OFFER, ACK, or NAK? 
  switch(*ptr) {

  case DHCP_OPTION_OFFER:
    // Okay, this was the server's offering.
    // Try to move into the confirmation phase

    // Because broken implementations of the server side
    // fail to set ciaddr correctly, I have to pull it out of the block of stupid

    while(NIFT_ipsystem.configured < 1) {

      // Skip the length of this block ahead.  Should be on next tag id.
      ptr += N;
      
      switch(*ptr) {

      case MESSAGE_TYPE_SELECTED_SERVER:
	// Advance to the length block (+1), then advance to the server block (+1)
	ptr += 2;
	//
	// Insane alignment behaviour again
	//	NIFT_ipsystem.dhcpserver = Xil_Ntohl(*(u32 *)ptr);
	//
	// TL;DR - If you try to dereference a memory location as a (u32 *) that
	//         does not sit on a 4 byte aligned address, uBlaze will shit on you.
	//         But if you do it as a (u8 *) life is good
	//
	memcpy(&NIFT_ipsystem.dhcpserver, ptr, 4);
	NIFT_ipsystem.dhcpserver = Xil_Ntohl(NIFT_ipsystem.dhcpserver);
	NIFT_ipsystem.configured = 1;
	dhcp_request();
	break;

      case MESSAGE_TYPE_END:
	// Something was fucked
	NIFT_ipsystem.configured = 0;
	break;
	
      default:
	// Skip this block
	N = *(++ptr);

	// Advance to the start of its data block so that we skip the correct number of bytes
	++ptr;
	break;
      }
    }
    return;

  case DHCP_OPTION_DECLINE:
  case DHCP_OPTION_NAK:
    // We were too slow on the draw
    // Restart the configuration process
    NIFT_ipsystem.configured = 0;
    return;

  case DHCP_OPTION_ACK:

    // Okay, this is the real deal guys.
    // We finally got our legit IP address.
    // We are a real human now.
    // We can  b r e e d.

    // Only need to parse this subset, because this is what we asked for.
    while(NIFT_ipsystem.configured < 2) {

      // We're on a message value, so advance to the next tag
      ptr += N;

      switch(*ptr) {
	
      case MESSAGE_TYPE_ROUTER:
	// Extract length field
	N = *(++ptr);

	// Advance to first router
	++ptr;
        memcpy(&NIFT_ipsystem.gateway, ptr, 4);
	NIFT_ipsystem.gateway = Xil_Ntohl(NIFT_ipsystem.gateway);
	break;

      case MESSAGE_TYPE_REQ_SUBNET_MASK:
	// Extract length
	N = *(++ptr);

	// Advance to the first subnet
	++ptr;
	memcpy(&NIFT_ipsystem.subnet_mask, ptr, 4);
	NIFT_ipsystem.subnet_mask = Xil_Ntohl(NIFT_ipsystem.subnet_mask);
	break;

      case MESSAGE_TYPE_END:
	NIFT_ipsystem.configured = 2;
	break;	
      }
    }
    break;
  default:
    // Its some field we don't know.
    // Pray to God that the fields are all treated as
    // dynamic in length, and that this is a length field.
    //
    // Explained:
    //  We are on a tag id block.
    //  ++ptr places on a length of following data block
    //  *(++ptr) extracts the length of the following data block
    //  ptr += *(++ptr) + 1  advances 1 to pass the length block and then N to pass the data
    N = *(++ptr);
    ++ptr;
    break;
  }
}

/*
 * UDP packet handler
 */
static void udp_input(struct NIFT_source *source, struct udphdr * udp_packet) {
  
  /* Check if there is a response from DHCP server by checking the source Port */

  // We push to dhcp processing the data minus the udp header
  if (Xil_Ntohs(udp_packet->uh_sport) == DHCP_SERVER_PORT) {
    dhcp_input((dhcp_t *)((char *)udp_packet + sizeof(struct udphdr)));
    return;
  }

  // If we're not configured, bail.
  if(NIFT_ipsystem.configured < 2)
    return;

  // We're configured.  Look for things we care about.  Things we need.
  if (Xil_Ntohs(udp_packet->uh_dport) == LAPPD_SERVER_PORT) {

    // Basic sanity.  The 3 are the stop bytes
    if(udp_packet->len < sizeof(struct lappd) + 3)
      return;

    // Okay.  Attempt to parse.
    source->sport = Xil_Ntohs(udp_packet->uh_sport);
    lappd_input(source, (lappd_t *)((char *)udp_packet + sizeof(struct udphdr)));
    return;
  }
  
}

static void lappd_input(struct NIFT_source *source, lappd_t *lappdhdr_in) {

  u32 tmp;
  u8 *ptr;
  u16 N, reg;
  u8 op;
  u8 *packet;
  int len;
  struct ip *ip_header;
  struct udphdr *udp_header;
  lappd_t *lappdhdr_out;
  u8 respond;
  
  // Verify that the magic is right
  if(Xil_Ntohl(lappdhdr_in->magic) != LAPPD_MAGIC_COOKIE)
    return;

  // Okay, we're probably going to send something back.
  // So start building a packet.
  // But even so, start in silent mode.
  respond = 0;
  
  // Do only 512 bytes for now.
  packet = memalign(4, 512 + HAX);
  packet += HAX;
  memset(packet, 0, 512);
  ip_header = (struct ip *)(packet + sizeof(struct ether_header));
  udp_header = (struct udphdr *)(((char *)ip_header) + sizeof(struct ip));
  lappdhdr_out = (lappd_t *)(((char *)udp_header) + sizeof(struct udphdr));

  // Initialize it
  lappdhdr_out->magic = Xil_Htonl(LAPPD_MAGIC_COOKIE);
  //  lappdhdr_out->version = Xil_Htonl(lappd.version);
  tmp = Xil_Htonl(lappd.version);
  memcpy(&lappdhdr_out->version, &tmp, 4);
  // Super annoying that I can't just assign things...

  // Use len as an offset into the payload first.  Then, before shipping
  // increment it by the lappd header length!
  len = 0;
  
  // Verify that the version is right
  if(Xil_Ntohl(lappdhdr_in->version) != lappd.version) {
    
    // Send the 0xFFFF register and the stop op 0xFF
    respond = 1;
    memset(lappdhdr_out->payload, 0xFF, 3);
    len += 3;

    // PS - We know these bytes are available, because we passed high-level sanity on packet size
  }

  // Process commands
  ptr = lappdhdr_in->payload;

  // Gotta grab the register and operation via memcpy, since uBlaze hates our freedoms.
  memcpy(&reg, ptr, 2);
  reg = Xil_Ntohs(reg);
  ptr += 2;
  memcpy(&op, ptr, 1);
  ++ptr;
  memcpy(&N, ptr, 2);
  N = Xil_Ntohs(N);
  ptr += 2;
  // We are now at the data region of the first request
   
  // Loop until end of requests
  while(op != 0xff) {
      
    // Check for reserved, its corrupt
    if(op & LAPPD_REG_MASK_RESERVED) {

      // Ack should always be low for requests
      free(packet - HAX);
      return;
    }
      
    // First implement reads
    switch(op & LAPPD_REG_MASK_OP) {

    case LAPPD_STATUS:
      // This is the same as a read, but offset +4 bytes in the register map
      reg += 0x0004;
      // Notice how we DO NOT break, but just slide into the LAPPD_READ ;)
    case LAPPD_READ:
      // Get the data length of this read request (should be zero)
      if(N) {
	// Something was corrupt, bail
	free(packet - HAX);
	return;
      }

      // Advance through the data block
      ptr += N;

      // Perform the read.
      NISHI_REG_READ(tmp, reg);
      tmp = Xil_Htonl(tmp);
	
      // If we requested silence on a read operation, we're retarded.
      // Or maybe we are crafty, like reading from a register sets off a nuclear
      // explosion that restores an educated electorate to the United States.
      if(op & LAPPD_REG_MASK_SILENT)
	break;
      else
	respond = 1;
		
      // Add the data and update the length
      // (send success always for now)
      op |= LAPPD_REG_MASK_ACK;

      // Rewrite out the register
      reg = Xil_Htons(reg);
      memcpy((u8 *)(lappdhdr_out->payload + len), &reg, 2);
      len += 2;

      // Rewrite out the operation
      memcpy((u8 *)(lappdhdr_out->payload + len), &op, 1);
      ++len;
	
      // Recycle: reg
      //   Was: register requested
      //    Is: a variable holding the length of the following data
      reg = Xil_Htons(4);
      memcpy((u8 *)(lappdhdr_out->payload + len), &reg, 2);
      len += 2;
      memcpy((u8 *)(lappdhdr_out->payload + len), &tmp, 4);
      len += 4;
      // Total written out: 9 bytes
	
      break;
	
    case LAPPD_WRITE:
      if(N != 4) {
	// Something was corrupt, bail
	free(packet - HAX);
	return;
      }
	
      // Read the data block into storage
      memcpy(&tmp, ptr, N); 
      tmp = Xil_Ntohl(tmp);
	
      // Write to the register
      NISHI_REG_WRITE(reg, tmp);

      // Advance through the data block
      ptr += N;

      // Did we request acknowledgment?
      if(!(op & LAPPD_REG_MASK_SILENT)) {

	// If anyone wishes to be heard, flag response
	respond = 1;
	  
	// Append acknowledgment information
	// Add the data and update the length
	// (send success always for now)
	op |= LAPPD_REG_MASK_ACK;

	// Can probably just move this pointer around, since the data
	// is definitely getting written into the block of memory
	reg = Xil_Htons(reg);
	memcpy((u8 *)(lappdhdr_out->payload + len), &reg, 2);
	len += 2;

	// Write out the op, with the ack flag set
	memcpy((u8 *)(lappdhdr_out->payload + len), &op, 1);
	++len;
	
	// Recycle: reg
	//   Was: the register of interest
	//    Is: a variable holding the length of the following data
	reg = Xil_Htons(4);
	memcpy((u8 *)(lappdhdr_out->payload + len), &reg, 2);
	len += 2;
	tmp = Xil_Htonl(tmp);
	memcpy((u8 *)(lappdhdr_out->payload + len), &tmp, 4);
	len += 4;
	// Total written out: 9 bytes
      }
      break;
    default:
      // Unknown operation, attempt to skip it
      // Advance through the data block
      ptr += N;	
      break;
    }

    // Get the next register and operation
    memcpy(&reg, ptr, 2);
    reg = Xil_Ntohs(reg);
    ptr += 2;
    memcpy(&op, ptr, 1);
    ++ptr;
    memcpy(&N, ptr, 2);
    N = Xil_Ntohs(N);
    ptr += 2;
    // We are now at the data region of the next request
  }

  // Did we have a mangled request and somehow not bail yet?
  if(len == 512) {

    // Cleanup and bail
    free(packet - HAX);
    return;
  }
  else {

    // Close the packet, since k = 0xFF
    // Do it with all 0xFFFFFF 
    memset((u8 *)(lappdhdr_out->payload + len), 0xFF, 3);
    len += 3;
  }

  // If we want the response (so at least one command was not silenced)
  // send it out.
  if(respond) {
      
    // We've completed our serialized list.
    // Increment len once more to capture the header length
    len += sizeof(struct lappd);
    
    // Send our response
    udp_output(udp_header, LAPPD_SERVER_PORT, source->sport, &len);
    ip_output(ip_header, Xil_Htonl(source->sip.s_addr), &len);

    // Don't like how we pass the actual value here... breaks with his other semantics
    // XXX Increase length by HAX because fuck you
    len += HAX;
    ether_output(packet, source->smacn, ETHERTYPE_IP, len);
  }
    
  // Clean up
  free(packet - HAX);

  // Since we don't have an arp table yet, we won't route
  // correctly off of the subnet.  But just send it back.
  // (this isn't real IP yet)
}

/*
 * IP Packet handler
 */
static void ip_input(struct NIFT_source *source, struct ip * ip_packet) {

  // We push to udp processing the data minus the ip header
  if (ip_packet->ip_p == IPPROTO_UDP) {
    source->sip = ip_packet->ip_src;
    udp_input(source, (struct udphdr *)((char *)ip_packet + sizeof(struct ip)));
  }
}

/*
 * Ethernet output handler - Fills appropriate bytes in ethernet header
 */
static void ether_output(u8 *frame, u8 *dmacn, short ethertype, int len) {

    struct ether_header *eframe = (struct ether_header *)frame;

    // Note that this is only for DHCP, since we are broadcasting (-1 rolls over)
    memcpy(eframe->ether_shost, NIFT_ipsystem.mac, ETHER_ADDR_LEN);
    memcpy(eframe->ether_dhost, dmacn,  ETHER_ADDR_LEN);
    eframe->ether_type = Xil_Htons(ethertype);

    len = len + sizeof(struct ether_header);

    sendFrame(frame, len);
}

static void arp_input(struct arphdr *arp_packet) {

  u32 tmp;
  u8 *packet;
  
  // Are we configured yet?  If not, bail
  if(NIFT_ipsystem.configured < 2)
    return;
  
  // Is it Ethernet arp?
  // This is a multibytye value
  if(arp_packet->ar_hrd != Xil_Htons(ARPHRD_ETHER))
    return;

  // Is it the ethernet protocol?
  if(arp_packet->ar_pro != Xil_Htons(ETHERTYPE_IP))
    return;

  // Does it have the right length?
  if(arp_packet->ar_hln != ETHER_ADDR_LEN)
    return;

  // Is the length of the protocol address correct for IP (since we are looking at ETHERTYPE_IP)
  // and v4 IP addresses are 4 bytes
  if(arp_packet->ar_pln != 4)
    return;

  // Is this an ARP request? (someone is asking for an id)
  if(arp_packet->ar_op != Xil_Htons(ARPOP_REQUEST))
    return;

  // Is someone looking for us?  (We're going to want our IP address in network order if it is)
  tmp = Xil_Htonl(NIFT_ipsystem.ip);
  if(memcmp(arp_packet->ar_tip, &tmp, 4))
    return;

  // Don't worry about the arp table yet
  //
  // Okay, they are asking about us.
  // First, add an arp table entry for this guy, because we will probably be talking to them again
  // XXX gotta make sure they aren't already in the arp table...
  /* if(NIFT_ipsystem.arpTableNext == ARP_TABLE_LEN) */
  /*   return; */

  /* // Cache it (we do lookups from the end) */
  /* memcpy(&NIFT_ipsystem.arpTable[NIFT_ipsystem.arpTableNext].mac_n, arp_packet->ar_sha, ETH_ALEN); */
  /* memcpy(&NIFT_ipsystem.arpTable[NIFT_ipsystem.arpTableNext].ipaddr_n, arp_packet->ar_sip, 4); */
  /* ++NIFT_ipsystem.arpTableNext; */
  
  // Construct an arp response by just modifying the entries in this packet and
  // sending it back out
  arp_packet->ar_op = Xil_Htons(ARPOP_REPLY);
  memcpy(arp_packet->ar_tha, arp_packet->ar_sha, ETH_ALEN);
  memcpy(arp_packet->ar_sha, &NIFT_ipsystem.mac, ETH_ALEN);
  memcpy(arp_packet->ar_sip, arp_packet->ar_tip, 4);
  memcpy(arp_packet->ar_tip, &tmp, 4);

  // Meh.  Let's not be shady.  Make a new packet, and populate it reasonably
  packet = memalign(4, sizeof(struct ether_header) + sizeof(struct arphdr) + HAX);
  if(!packet) {
    errno = ENOMEM;
    return;
  }
  packet += HAX;
  memset(packet, 0, sizeof(struct ether_header) + sizeof(struct arphdr) + HAX);
  
  //
  // Recycle: tmp
  //   Was: our ip address in network byte order
  //   Is:  The length of our packet
  //
  tmp = sizeof(struct arphdr);
  memcpy(packet + sizeof(struct ether_header), arp_packet, tmp);
  ether_output(packet, arp_packet->ar_tha, ETHERTYPE_ARP, tmp);
  free(packet - HAX);
}

/*
 * Ethernet packet handler
 */
static void ether_input(const u8 *frame) {

  // We cast as ether header, so that we can offset into the first bytes.
  struct ether_header *eframe = (struct ether_header *)frame;
  ushort ethertype;

  // Gross hacks.
  struct NIFT_source source;
    
  ethertype = Xil_Ntohs(eframe->ether_type);

  switch(ethertype) {
    
  case ETHERTYPE_IP:
    memcpy(&source.smacn, eframe->ether_shost, ETH_ALEN);
    ip_input(&source, (struct ip *)(frame + sizeof(struct ether_header)));
    break;
  case ETHERTYPE_ARP:
    arp_input((struct arphdr *)(frame + sizeof(struct ether_header)));
    break;
  default:
    break; 
  }
}

// This can now be used to wrap arbitrary IP packets heading to dst. 
static void ip_output(struct ip *ip_header, u32 dst, int *len) {
  
    *len += sizeof(struct ip);

    ip_header->ip_hl = 5;
    ip_header->ip_v = 4; //IPVERSION;
    ip_header->ip_tos = 0x10;
    ip_header->ip_len = Xil_Htons(*len);
    ip_header->ip_id = Xil_Htons(0xffff);
    ip_header->ip_off = 0;
    ip_header->ip_ttl = 16;
    ip_header->ip_p = 17; //IPPROTO_UDP;
    ip_header->ip_sum = 0;

    // If we're not yet configured, send from the aether
    if(NIFT_ipsystem.configured < 2)
      ip_header->ip_src.s_addr = 0x0;
    else
      ip_header->ip_src.s_addr = Xil_Htonl(NIFT_ipsystem.ip);

    // Set the destination
    ip_header->ip_dst.s_addr = Xil_Htonl(dst);
    
    ip_header->ip_sum = in_cksum((unsigned short *) ip_header, sizeof(struct ip));
}

/*
 * UDP output - Fills appropriate bytes in UDP header
 */
static void udp_output(struct udphdr *udp_header, u16 sport, u16 dport, int *len) {

  // KC 10/22/18
  // ??? What's this doing?
  if (*len & 1)
    *len += 1;
  *len += sizeof(struct udphdr);
  
  udp_header->uh_sport = Xil_Htons(sport);
  udp_header->uh_dport = Xil_Htons(dport);
  udp_header->uh_ulen = Xil_Htons(*len);
  udp_header->uh_sum = 0;
}

static void dhcp_output(dhcp_t *dhcp, u_int8_t *mac, int *len)
{
    *len += sizeof(dhcp_t);
    memset(dhcp, 0, sizeof(dhcp_t));

    // This is the same for the DISCOVER and REQUEST
    dhcp->opcode = DHCP_BOOTREQUEST;
    dhcp->htype = DHCP_HARDWARE_TYPE_10_EHTHERNET;
    dhcp->hlen = 6;
    memcpy(dhcp->chaddr, mac, DHCP_CHADDR_LEN);

    dhcp->magic_cookie = Xil_Htonl(DHCP_MAGIC_COOKIE);
}

/*
 * Adds DHCP option to the bytestream
 */
static int fill_dhcp_option(u_int8_t *packet, u_int8_t code, u_int8_t *data, u_int8_t len)
{
    packet[0] = code;
    packet[1] = len;
    memcpy(&packet[2], data, len);

    return len + (sizeof(u_int8_t) * 2);
}

/*
 * Fill DHCP options
 */
static int fill_dhcp_discovery_options(dhcp_t *dhcp) {
  
  int len = 0;
  u32 req_ip;
  u8 parameter_req_list[] = {MESSAGE_TYPE_REQ_SUBNET_MASK, MESSAGE_TYPE_ROUTER};
  u8 option;

  option = DHCP_OPTION_DISCOVER;
  len += fill_dhcp_option(&dhcp->bp_options[len], MESSAGE_TYPE_DHCP, &option, sizeof(option));
  req_ip = Xil_Htonl(0xc0a8010a);
  len += fill_dhcp_option(&dhcp->bp_options[len], MESSAGE_TYPE_REQ_IP, (u8 *)&req_ip, sizeof(req_ip));
  len += fill_dhcp_option(&dhcp->bp_options[len], MESSAGE_TYPE_PARAMETER_REQ_LIST, (u8 *)&parameter_req_list, sizeof(parameter_req_list));
  option = 0;
  len += fill_dhcp_option(&dhcp->bp_options[len], MESSAGE_TYPE_END, &option, sizeof(option));

  return len;
}

static int fill_dhcp_request_options(dhcp_t *dhcp) {

  int len = 0;
  u8 option;
  u32 buf;
  
  // Set up 53: 3
  option = DHCP_OPTION_REQUEST;
  len += fill_dhcp_option(&dhcp->bp_options[len], MESSAGE_TYPE_DHCP, &option, sizeof(option));

  // Set up 50
  buf = Xil_Htonl(NIFT_ipsystem.ip);
  len += fill_dhcp_option(&dhcp->bp_options[len], MESSAGE_TYPE_REQ_IP, (u8 *)&buf, sizeof(buf));

  // Set up 54
  buf = Xil_Htonl(NIFT_ipsystem.dhcpserver);
  len += fill_dhcp_option(&dhcp->bp_options[len], MESSAGE_TYPE_SELECTED_SERVER, (u8 *)&buf, sizeof(buf));

  // Close the options block
  option = 0; 
  len += fill_dhcp_option(&dhcp->bp_options[len], MESSAGE_TYPE_END, &option, sizeof(option));

  return len;
}

static int dhcp_request(void) {
  
  int len = 0;
  u8 *packet;
  struct udphdr *udp_header;
  struct ip *ip_header;
  dhcp_t *dhcp;
  u8 buf[ETH_ALEN];
  
  // Dynamic allocate, because weird af behaviour
  packet = (u8 *)memalign(4, 512 + HAX);
  if(!packet)
    return 1;

  // Now advance by 2 because the 
  packet += HAX;
    
  memset(packet, 0, 512);
    
  // Index into the packet cleverly!
  ip_header = (struct ip *)(packet + sizeof(struct ether_header));
  udp_header = (struct udphdr *)(((char *)ip_header) + sizeof(struct ip));
  dhcp = (dhcp_t *)(((char *)udp_header) + sizeof(struct udphdr));
 
  // Populate DHCP payload
  len = fill_dhcp_request_options(dhcp);
  dhcp_output(dhcp, NIFT_ipsystem.mac, &len);

  // Populate udp header
  udp_output(udp_header, DHCP_CLIENT_PORT, DHCP_SERVER_PORT, &len);

  // Populate IP header
  ip_output(ip_header, 0xffffffff, &len);

  // Populate ethernet header and ship
  memset(buf, -1, ETH_ALEN);
  ether_output(packet, buf, ETHERTYPE_IP, len);

  // Clean up
  free(packet - HAX);
  return 0;
}

/*
 * Send DHCP DISCOVERY packet
 */
    		
static int dhcp_discovery(void) {

  int len = 0;

  u8 *packet;
  struct udphdr *udp_header;
  struct ip *ip_header;
  dhcp_t *dhcp;
  u8 buf[ETH_ALEN];
  
  // Dynamic allocate, because weird af behaviour
  packet = (u8 *)memalign(4, 512 + HAX);
  if(!packet)
    return 1;

  // Now advance by 2 because the 
  packet += HAX;
    
  memset(packet, 0, 512);
    
  // Index into the packet cleverly!
  ip_header = (struct ip *)(packet + sizeof(struct ether_header));
  udp_header = (struct udphdr *)(((char *)ip_header) + sizeof(struct ip));
  dhcp = (dhcp_t *)(((char *)udp_header) + sizeof(struct udphdr));
 
  // Populate DHCP payload
  len = fill_dhcp_discovery_options(dhcp);
  dhcp_output(dhcp, NIFT_ipsystem.mac, &len);

  // Populate udp header
  udp_output(udp_header, DHCP_CLIENT_PORT, DHCP_SERVER_PORT, &len);

  // Populate IP header
  ip_output(ip_header, 0xffffffff, &len);

  // Populate ethernet header and ship
  memset(buf, -1, ETH_ALEN);
  ether_output(packet, buf, ETHERTYPE_IP, len);

  // Clean up
  free(packet - HAX);
  return 0;
}

int main(void) {
  
  u32 result;

  // Set the version of this board
  NISHI_REG_READ(lappd.version, INTERNAL_OFFSET | REG_INTERNAL_VERSION);
  
  // Set up cache for incoming ethernet frames
  initMemory();
    
  /* Get the MAC address of the interface */
  result = get_mac_address(NIFT_ipsystem.mac);
    
  // If this doesn't work, something is badly broken with the IOmodule.
  // Just die.
  if (result)
    return 1; 

  // Initialize an empty arp table
  NIFT_ipsystem.arpTableNext = 0;

  // Get on the intarwebs
  while(1) {

    // Send DHCP DISCOVERY packet
    if(!NIFT_ipsystem.configured) {
	
      result = dhcp_discovery();
      if(result)
	return 1;
    }
      
    // Intake 10 frames and try to complete the negotiation
    // This should be changed to a timeout...
    result = 10;
    while(NIFT_ipsystem.configured < 2 && --result > 0) {
      NIFT_intakeFrame();
      ether_input(gInboundData);
      resetFrame();
    }
      
    // We didn't complete the negotiation.  Try again with another offer.
    if(NIFT_ipsystem.configured < 2) {
      //sleep(1);
      int blorf;
      for (blorf = 0; blorf < 7500000; ++blorf) {}
      NIFT_ipsystem.configured = 0;
    }
    else
      break;
  }

  // Ip system is configured.  Set the values into the registers
  NISHI_REG_WRITE(LAPPD_OFFSET | REG_LAPPD_SRCIP, Xil_Htonl(NIFT_ipsystem.ip));

  // Recycle: result
  //   Was: return values from functions used during configuration
  //    Is: temporary stash for grabbing longer than 4 byte things
  //
  // Low is set to the first two bytes
  result = 0;

  // XXX uBlaze is going to shit itself here...
  memcpy(&result, NIFT_ipsystem.mac, 2);
  NISHI_REG_WRITE(LAPPD_OFFSET | REG_LAPPD_SRCMAC_LOW, result);

  // High is set to the last 4 bytes
  memcpy(&result, NIFT_ipsystem.mac + 2, 4);
  NISHI_REG_WRITE(LAPPD_OFFSET | REG_LAPPD_SRCMAC_HIGH, result);
		  
  // We escaped the configuration loop, so we're online.
  while(1) {

    // Process frames
    NIFT_intakeFrame();
    ether_input(gInboundData);
    resetFrame();
  }
  
  // Clean up the frame
  free(gInboundData - 2);
}
