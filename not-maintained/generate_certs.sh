# make dirs, database, and certs
cd /home/ubuntu
mkdir -p certs
rm -rf certs/*
sudo chmod 0700 certs private
cd certs

#create certificate authority
openssl genrsa 2048 > ca-key.pem
openssl req -new -x509 -nodes -days 365000 \
      -key ca-key.pem -out ca-cert.pem -config ../openssl.cnf
echo "done creating CA"

#create server cert
openssl req -newkey rsa:2048 -days 365000 \
      -nodes -keyout server-key.pem -out server-req.pem -config ../openssl.cnf
openssl rsa -in server-key.pem -out server-key.pem
openssl x509 -req -in server-req.pem -days 365000 \
      -CA ca-cert.pem -CAkey ca-key.pem -set_serial 01 \
      -out server-cert.pem
# Add dh cert with 1024 bit for dh key too small.
openssl dhparam -out dhparams.pem 2048
cat dhparams.pem >> server-cert.pem
echo "done creating server.pem"

#create client cert,  Requires different fqdn than server
openssl req -newkey rsa:2048 -days 365000 \
      -nodes -keyout client-key.pem -out client-req.pem -config ../openssl.cnf
openssl rsa -in client-key.pem -out client-key.pem
openssl x509 -req -in client-req.pem -days 365000 \
      -CA ca-cert.pem -CAkey ca-key.pem -set_serial 01 \
      -out client-cert.pem
echo "done creating client.pem"

#verify certs
openssl verify -CAfile ca-cert.pem \
      server-cert.pem client-cert.pem