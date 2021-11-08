# lcls2-pgp-fb
Feedback routing of LCLS2 PGP application streams

Firmware for PCIe boards that receive multiple PGP application streams and select a double word from one lane and virtual channel.  The non-feedback stream is treated as an ordinary PGP stream with inbound/outbound DMAs, except that virtual channel 1 DMAs are dropped if they might backpressure the inbound PGP stream.  This is to prevent software from rate-limiting the outgoing feedback stream.