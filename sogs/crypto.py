from . import config

import os

from nacl.public import PrivateKey
from nacl.signing import SigningKey, VerifyKey
from nacl.encoding import Base64Encoder, HexEncoder

from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.asymmetric.x25519 import X25519PrivateKey, X25519PublicKey

import secrets
import hmac

import pyonionreq

# generate seed as needed
if not os.path.exists(config.KEY_FILE):
    with open(os.open(config.KEY_FILE, os.O_CREAT | os.O_WRONLY, 0o400), 'wb') as f:
        f.write(PrivateKey.generate().encode())

with open(config.KEY_FILE, 'rb') as f:
    _privkey = PrivateKey(f.read())

server_pubkey = _privkey.public_key

server_pubkey_bytes = server_pubkey.encode()
server_pubkey_hex = server_pubkey.encode(HexEncoder).decode('ascii')
server_pubkey_base64 = server_pubkey.encode(Base64Encoder).decode('ascii')

_junk_parser = pyonionreq.junk.Parser(privkey=_privkey.encode(), pubkey=server_pubkey.encode())
parse_junk = _junk_parser.parse_junk


def verify_sig_from_pk(data, sig, pk):
    return VerifyKey(pk).verify(data, sig)


_server_signkey = SigningKey(_privkey.encode())

server_verify = _server_signkey.verify_key.verify

server_sign = _server_signkey.sign


def server_encrypt(pk, data):
    nonce = secrets.token_bytes(12)
    pk = X25519PublicKey.from_public_bytes(pk)
    sk = X25519PrivateKey.from_private_bytes(_privkey.encode())
    secret = hmac.digest(b'LOKI', sk.exchange(pk), 'SHA256')
    return nonce + AESGCM(secret).encrypt(nonce, data, None)
