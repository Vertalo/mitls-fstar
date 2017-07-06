#include <stdio.h>
#include <memory.h>
#include <unistd.h>
#include <assert.h>
#include <sys/stat.h>
#include <sys/cdefs.h>
#if __APPLE__
#include <sys/errno.h> // OS/X only provides include/sys/errno.h
#else
#include <errno.h> // MinGW only provides include/errno.h
#include <malloc.h>
#endif
#include "mitlsffi.h"

void dump(unsigned char buffer[], size_t len)
{
  int i; 
  for(i=0; i<len; i++) {
    printf("%02x",buffer[i]);
    if (i % 32 == 31 || i == len-1) printf("\n");
  }
}

char *quic_result_string(quic_result r){
  switch(r) {
    case TLS_would_block: return "would_block";
    case TLS_error_local: return "error_local";
    case TLS_error_alert: return "error_alert";
    case TLS_client_early: return "client_early";
    case TLS_client_complete: return "client_complete";
    case TLS_client_complete_with_early_data: return "client_complete_ED";
    case TLS_server_accept: return "server_accept";
    case TLS_server_accept_with_early_data: return "server_accept_ED";
    case TLS_server_complete: return "server_complete";
    default: return "other_error";
  }
}

int main(int argc, char **argv)
{
  char *errmsg;
  quic_result rc, rs;

  quic_config config = {
    .is_server = 1,
    .host_name = "",
    .qp = {
      .max_stream_data = 16000,
      .max_data = 32000,
      .max_stream_id = 16,
      .idle_timeout = 60
    },
    .certificate_chain_file = "../../data/server-ecdsa.crt",
    .private_key_file = "../../data/server-ecdsa.key",
    .ca_file = "../../data/CAFile.pem",
    .cipher_suites = NULL, // Use defaults
    .signature_algorithms = "ECDSA+SHA256",
    .named_groups = "X25519",
    .ticket_enc_alg = NULL,
    .ticket_key = NULL,
    .ticket_key_len = 0,
    .enable_0rtt = 1
  };

  quic_state *server;
  quic_state *client;

  FFI_mitls_init();

  printf("server create\n");
  if(!FFI_mitls_quic_create(&server, &config, &errmsg))
  {
    printf("quic_create server failed: %s\n", errmsg);
    return -1;
  }

  config.is_server = 0;
  config.host_name = "localhost";

  printf("client create\n");
  if(!FFI_mitls_quic_create(&client, &config, &errmsg))
  {
    printf("quic_create client failed: %s\n", errmsg);
    return -1;
  }

  // server writer buffer (cumulative)
  size_t slen = 0;
  size_t smax = 8*1024; // too much; we use < 1KB
  char *s_buffer = malloc(smax);

  // client write buffer (cumulative)
  size_t clen = 0;
  size_t cmax = 8*1024; // too much; we use < 1KB
  char *c_buffer = malloc(clen); // 
  int client_complete = 0;
  int server_complete = 0;

  do{
    c_buffer += clen; // assuming miTLS never returns a larger clen
    cmax -= clen;
    clen = cmax;

    printf("client call clen=%4d slen=%4d\n", clen, slen);
    rc = FFI_mitls_quic_process(client, s_buffer, &slen, c_buffer, &clen, &errmsg);
    printf("client done clen=%4d slen=%4d r=%s\n", clen, slen, quic_result_string(rc));
    dump(c_buffer, clen);
  
    client_complete |= rc == TLS_client_complete || rc == TLS_client_complete_with_early_data;
    if(rc == TLS_error_other || rc == TLS_error_local || rc == TLS_error_alert){
      printf("Stopping due to error code. Msg: %s\n", errmsg);
      break;
    }

    s_buffer += slen; // assuming miTLS never returns a larger clen
    smax -= slen;
    slen = smax;
    
    /* clen -= 12; // simulating fragmentation */
    /* printf("server call clen=%4d slen=%4d\n", clen, slen); */
    /* rs = FFI_mitls_quic_process(server, c_buffer, &clen, s_buffer, &slen, &errmsg); */
    /* printf("server done clen=%4d slen=%4d rc=%d\n", clen, slen, rc); */
    /* clen += 12; */

    printf(" *** START SERVER clen=%4d slen=%4d\n", clen, slen);
    rs = FFI_mitls_quic_process(server, c_buffer, &clen, s_buffer, &slen, &errmsg);
    printf(" *** END SERVER clen=%4d slen=%4d r=%s\n", clen, slen, quic_result_string(rs));
    printf("  === Server output ===\n");
    dump(s_buffer, slen);
    printf("  =====================\n");

    server_complete |= rs == TLS_server_complete;
    if(rs == TLS_error_other || rs == TLS_error_local || rs == TLS_error_alert){
      printf("Stopping due to error code. Msg: %s\n", errmsg);
      break;
    }

  }
  while(!client_complete || !server_complete);

  FFI_mitls_cleanup();
  printf("Ok\n");
  return 0;
}
