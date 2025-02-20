from flask import abort, render_template, Response
from ..web import app
from .. import config, crypto, http, utils
from ..model.room import get_readable_rooms

from . import auth, converters  # noqa: F401

from .legacy import legacy as legacy_endpoints
from .general import general as general_endpoints
from .onion_request import onion_request as onion_request_endpoints
from .rooms import rooms as rooms_endpoints
from .users import users as users_endpoints

from io import BytesIO

import qrencode

from PIL.Image import NEAREST


app.register_blueprint(legacy_endpoints)
app.register_blueprint(general_endpoints)
app.register_blueprint(onion_request_endpoints)
app.register_blueprint(rooms_endpoints)
app.register_blueprint(users_endpoints)


@app.get("/")
def serve_index():
    rooms = get_readable_rooms()
    if len(rooms) == 0:
        return render_template('setup.html')
    return render_template(
        "index.html", url_base=config.URL_BASE, rooms=rooms, pubkey=crypto.server_pubkey_hex
    )


@app.get("/view/room/<Room:room>")
def view_room(room):
    if not room.default_read:
        abort(http.FORBIDDEN)

    return render_template(
        "view_room.html",
        room=room.token,
        room_url=utils.server_url(room.token),
        show_recent=config.HTTP_SHOW_RECENT,
    )


@app.get("/view/<Room:room>/invite.png")
def serve_invite_qr(room):
    if not room.default_read:
        abort(http.FORBIDDEN)

    img = qrencode.encode(utils.server_url(room.token))
    data = BytesIO()
    img = img[-1].resize((512, 512), NEAREST)
    img.save(data, "PNG")
    return Response(data.getvalue(), mimetype="image/png")
