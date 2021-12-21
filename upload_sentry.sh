#!/bin/bash
sentry-cli --auth-token 6385f86e5a554b61a6da108c6a14a23f7e416818801c456393e7bfb2d440eadd upload-dif --org cloudveil-technology --project cvm-ios  "$1"/*.dSYM
