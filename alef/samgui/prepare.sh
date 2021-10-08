#!/bin/bash

scp -J afarah@portal.inf.ufrgs.br cramlist_remote gppd1@143.54.48.77:/DATA/alef/samgui_test/cramlist_remote
scp -J afarah@portal.inf.ufrgs.br download_data.sh gppd1@143.54.48.77:/DATA/alef/samgui_test/
./exec_remote.sh -r gppd1@143.54.48.77 -J afarah@portal.inf.ufrgs.br exec_docker.sh ubuntu-samtools /DATA/alef/samgui_test/download_data.sh /DATA/alef/samgui_test/data /DATA/alef/samgui_test/cramlist_remote
