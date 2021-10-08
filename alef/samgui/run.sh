#!/bin/bash

scp -J afarah@portal.inf.ufrgs.br variant_call.sh gppd1@143.54.48.77:/DATA/alef/samgui_test
./exec_remote.sh -r gppd1@143.54.48.77 -J afarah@portal.inf.ufrgs.br exec_docker.sh ubuntu-samtools /DATA/alef/samgui_test/variant_call.sh /DATA/alef/samgui_test /DATA/alef/samgui_test/data/cramlist_local
