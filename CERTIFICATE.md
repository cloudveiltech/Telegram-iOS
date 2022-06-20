# Hp To Update Push Certificate
1. Download cert from appstore
2. Import it to your mac
3. Export it from your mac to p12 format
4. run this command with your cert
5. openssl pkcs12 -in apns-dev-cert.p12 -out apns-dev-cert.pem -nodes -clcerts
6. Upload resulting file to my.telegram.org
