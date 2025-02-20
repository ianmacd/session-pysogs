import sogs.model.user
from nacl.public import PrivateKey


class User(sogs.model.user.User):
    def __init__(self):
        self.privkey = PrivateKey.generate()

        super().__init__(session_id="05" + self.privkey.public_key.encode().hex(), touch=True)
