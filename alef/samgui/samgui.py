from guietta import _, ___, C, P, Gui, Quit
try:
  from PySide2.QtWidgets import QMessageBox
except ImportError:
  from PyQt5.QtWidgets import QMessageBox
from subprocess import Popen, PIPE, call
import logging
import os
from time import sleep
from pathlib import Path
import signal
import sys

logging.basicConfig(level=os.environ.get("LOGLEVEL", "INFO"), format='SAMGUI: %(asctime)s %(levelname)s %(name)s %(message)s')
log = logging.getLogger(__name__)

class SamGUIException(Exception):
  pass

g_refMsg = ', refer to command line output for details.'
g_dockerCmd = ''
g_remoteCmd = ''
g_UserProcess = None
g_StatusProcess = None
c_defaultFilter = '--max-missing 0.5 --minDP 5 --min-alleles 2 --max-alleles 2 --minQ 20' 

gui = Gui(
  [ '<b>Remote environment configuration</b>', ___, _, _, _, _],
  [ 'Remote host*', '__remote__', (['Help'], 'help_remote'), 'Hop host', '__hop__', (['Help'], 'help_hop') ],
  [ 'Docker image name*','__docker__', (['Help'], 'help_docker'), 'Data path*', '__data__', (['Help'], 'help_data') ],
  [ '<b>Input list configuration</b>', ___, _, _, _, _],
  [ 'Download CRAM list', '__ftp__', (['Help'], 'help_ftp'), 'Local CRAM list', '__local__', (['Help'], 'help_local')],
  [ '<b>Variant calling configuration</b>', ___, _, _, _, _],
  [ 'VCF filter params*','__vcffilter__', ___ , ___, (C('Keep indels'), 'keep'), (['Help'], 'help_filter')],
  [ '<b>Commands</b>', ___, _, _, _, _],
  [ (['Check status'], 'status'), (['Run variant call'], 'vcall'), (['Run download'], 'download'), _, _, _],
  [ (['Abort all'], 'abort'), (['Run all'], 'runall'), ___, (C('Skip setup'), 'skip'), _, _],
  [ '<b>Status</b>', ___, _, _, _, _],
  [ 'state', P('progress'), ___, ___, ___, ___],
  title='SAMGUI'
)

def set_defaults():
  gui.remote = 'user@host'
  gui.hop = 'user@hophost'
  gui.ftp = ''
  gui.local = 'cramlist_local'
  gui.docker = 'afarah1/ubuntu-samtools'
  gui.data = '/DATA'
  gui.vcffilter = c_defaultFilter
  gui.progress = 0
  gui.state = 'Idle'

def tostring(gui):
  return ','.join([gui.remote, gui.hop, gui.ftp, gui.local, gui.docker, gui.data, gui.vcffilter, str(gui.keep.isChecked()), str(gui.skip.isChecked())])

def fromstring(string):
  gui.remote, gui.hop, gui.ftp, gui.local, gui.docker, gui.data, gui.vcffilter, keep, skip = string.split(',')
  gui.keep.setChecked(keep == "True")
  gui.skip.setChecked(skip == "True")

def save_state():
  log.debug('Saving state')
  try:
    Path('samgui.state').write_text(tostring(gui))
  except Exception as e:
    log.warning('Could not write to samgui.state')

def load_state():
  log.debug('Loading state')
  # Load program state
  try:
    fromstring(Path('samgui.state').read_text())
  except FileNotFoundError:
    log.debug('samgui.state not found')
  except Exception as e:
    log.warning('samgui.state not readable: %s' % e)

def update_filter_file():
  # Update filter file
  try:
    Path('samgui.filter').write_text(gui.vcffilter)
  except Exception as e:
    log.error('Could not write VCF filter to file: %s' % e)

def handle_sigint(sig, frame):
  log.debug('Received SIGINT, saving state. Send SIGTERM or SIGKILL if necessary')
  try:
    save_state()
  finally:
    sys.exit(0)

def validate_input_common():
  if gui.remote == '':
    raise SamGUIException('Local execution not supported :(') # TODO support this
  if gui.hop != '' and gui.remote == '':
    raise SamGUIException('Hop host but no remote host supplied.')
  if gui.data == '':
    raise SamGUIException('Data path not supplied')
  if gui.docker == '':
    log.info('No docker image supplied, using afarah1/ubuntu-samtools')
    gui.docker = 'afarah1/ubuntu-samtools'

def validate_input_download():
  validate_input_common()
  if gui.ftp == '':
    raise SamGUIException('Requested download but no download list supplied.')

def validate_input_vcall():
  validate_input_common()
  if gui.local == '':
    raise SamGUIException('Requested variant call but no local list supplied. To download then do variant call press Run all.')

def validate_input_runall():
  validate_input_common()

def validate_input_status():
  validate_input_common()

def validate_input_abort():
  validate_input_common()

def set_status(state, progress):
  gui.state = state
  gui.progress = progress

def build_cmds():
  global g_dockerCmd
  global g_remoteCmd
  g_dockerCmd = './exec_remote.sh -r ' + gui.remote
  if gui.hop != '':
    g_dockerCmd += ' -J ' + gui.hop
  g_dockerCmd += ' --'
  g_remoteCmd = g_dockerCmd
  g_dockerCmd += ' exec_docker.sh y ' + gui.docker + ' ' + gui.data

def ask_kill():
  ans = QMessageBox.question(None, "Question", "Another process is already running. Terminate it?")
  return ans == QMessageBox.Yes

def check_userp_running():
  global g_UserProcess
  if g_UserProcess != None:
    if g_UserProcess.poll() is not None:
      log.debug('Process terminated with return code: %s' % g_UserProcess.returncode) 
      g_UserProcess = None
    elif ask_kill():
      log.debug('Process already running, user asked to terminate. Terminating.')
      g_UserProcess.terminate()
    else:
      log.debug('Process already running, user did wish to terminate. Returning.')
      return True
  return False

def check_statusp_running():
  global g_StatusProcess
  if g_StatusProcess != None:
    if g_StatusProcess.poll() is not None:
      log.debug('Status process terminated with return code: %s' % g_StatusProcess.returncode) 
      if g_StatusProcess.returncode != 0:
        stdout, stderr = g_StatusProcess.communicate()
        log.debug('Non-zero rc. stdout, stderr: %s %s' % (stdout, stderr))
        set_status('Idle', 0)
      else:
        status = g_StatusProcess.communicate()[0].decode('utf-8').splitlines()[-1].split(',')
        if len(status) != 3:
          log.error('Unexpected contents of samgui.status: %s ' % ', '.join(map(str,status)))
        progress = int((float(status[1]) / float(status[2])) * 100)
        if status[0] == '1':
          set_status('Downloading', progress)
        elif status[0] == '2':
          set_status('Variant calling', progress)
        else:
          log.error('Unexpected contents of samgui.status: %s' % ', '.join(map(str,status)))
      g_StatusProcess = None
    else:
      return True
  return False

def prepare_env():
  global g_UserProcess
  if check_userp_running():
    log.info('Not preparing remote environment since another process is already running.')
    return
  if gui.skip.isChecked():
    log.info('Not preparing remote environment since setup skipping was checked.')
    return
  log.info('Preparing remote environment ' + gui.remote + ' hop ' + gui.hop)
  update_filter_file()
  g_UserProcess = Popen('./prepare.sh %s %s %s' % (gui.remote, gui.data, gui.hop), shell=True)
  # TODO this hangs the GUI, not ideal...
  i = 0
  while g_UserProcess.poll() is None:
    set_status('Preparing', min(i, 50))
    i += 1
    sleep(0.5)
  if g_UserProcess.returncode != 0:
    raise SamGUIException('Remote host preparation failed' + g_refMsg)
  set_status('Preparing', 50)
  g_UserProcess = Popen([g_remoteCmd + ' prepare_docker.sh ' + gui.docker], shell=True)
  # TODO this hangs the GUI, not ideal...
  i = 50
  while g_UserProcess.poll() is None:
    set_status('Preparing', min(i, 100))
    i += 1
    sleep(0.5)
  if g_UserProcess.returncode != 0:
    raise SamGUIException('Remote host docker preparation failed' + g_refMsg)
  set_status('Preparing', 100)
  sleep(0.5)

def build_and_prepare():
  build_cmds()
  prepare_env()

def download_files(cramlist_remote):
  global g_UserProcess
  if check_userp_running():
    log.info('Not downloading files since another process is already running.')
    return
  log.info('Downloading files')
  download_cmd = ' /DATA/download_data.sh /DATA/ /DATA/' + gui.ftp
  set_status('Downloading', 0)
  g_UserProcess = Popen([g_dockerCmd + download_cmd], shell=True)

def do_vcall():
  global g_UserProcess
  log.info('Starting variant calling')
  if check_userp_running():
    log.info('Not calling variants since another process is already running.')
    return
  call_cmd = ' /DATA/variant_call.sh /DATA/cramlist_local'
  if gui.vcffilter != '' and gui.vcffilter != c_defaultFilter:
    call_cmd += ' -f /DATA/samgui.filter'
  if gui.keep.isChecked():
    call_cmd += ' -i'
  set_status('Variant calling', 0)
  g_UserProcess = Popen([g_dockerCmd + call_cmd], shell=True)

def check_status(sender):
  global g_StatusProcess
  if not gui.is_running: 
    log.debug('GUI not running, not checking status')
    return
  if g_remoteCmd == '' and sender is not None:
    log.debug('Poll check but nothing requested yet, not checking status')
    return
  if check_statusp_running():
    log.debug('Already waiting for another status check, not checking again')
    return
  if sender is None:
    log.info('Checking status')
  else:
    log.debug('Poll status check')
  status_cmd = g_remoteCmd + ' exec_docker.sh n ' + gui.docker + ' ' + gui.data + ' cat /tmp/samgui.status'
  g_StatusProcess = Popen([status_cmd], stdout=PIPE, shell=True)

def abort_all():
  log.info('Aborting everything')
  rc = call(g_remoteCmd + ' docker stop samgui', shell=True)
  if rc != 0:
    rc = call(g_remoteCmd + ' docker ps | grep samgui', shell=True)
    if rc != 0:
      log.info('Could not abort because it is not running in the first place')
      #set_status('Idle', 0) --- Do not do this. Wait for async check, otherwise it won't sync up
    else:
      log.warning('Could not abort, please do it manually' + g_refMsg)
  else:
    #set_status('Idle', 0) --- Do not do this. Wait for async check, otherwise it won't sync up
    rc = call(g_remoteCmd + ' docker container rm samgui', shell=True)
    if rc != 0:
      log.warning('Could not remove stopped container, please remove it manually by running docker container prune')
    else:
      log.debug('Sucessfully removed container')

with gui.help_remote:
  if gui.is_running:
    log.debug('help_remote pressed')
    QMessageBox.information(None, "Info", "Remote host where the variant calling pipeline should be executed. Format: user@hostname.") 

with gui.help_hop:
  if gui.is_running:
    log.debug('help_hop pressed')
    QMessageBox.information(None, "Info", "Optional - host to hop through to get to the remote host. Format: user@hostname.")

with gui.help_ftp:
  if gui.is_running:
    log.debug('help_ftp pressed')
    QMessageBox.information(None, "Info", "Optional - list of URLs to download CRAMs from. If not supplied, you must supply a local CRAM list.")

with gui.help_local:
  if gui.is_running:
    log.debug('help_local pressed')
    QMessageBox.information(None, "Info", "Optional - list of CRAM, FASTA, VCF.GZ, and TBI/CSI files already present on the remote host to be used. If not supplied, you must supply a remote CRAM list to download from.")

with gui.help_docker:
  if gui.is_running:
    log.debug('help_docker pressed')
    QMessageBox.information(None, "Info", "Docker image name to be used. Must be present on the remote host or able to pull from a public repo configured on the host.")

with gui.help_data:
  if gui.is_running:
    log.debug('help_data pressed')
    QMessageBox.information(None, "Info", "Path on the remote host where the data is or will be once downloaded. A mount point to this location will be accessed from docker.")

with gui.help_filter:
  if gui.is_running:
    log.debug('help_filter pressed')
    QMessageBox.information(None, "Info", "Parameters for VCF filtering during variant calling. Check 'keep indels' if you do not wish to remove indels from VCF.")

with gui.runall:
  if gui.is_running:
    log.info('Run requested.')
    validate_input_runall()
    build_and_prepare()
    if gui.ftp != '':
      download_files(gui.ftp)
    do_vcall()

with gui.download:
  if gui.is_running:
    log.info('Download request.')
    validate_input_download()
    build_and_prepare()
    download_files(gui.ftp)

with gui.vcall:
  if gui.is_running:
    log.info('Variant call requested.')
    validate_input_vcall()
    build_and_prepare()
    do_vcall()

with gui.status:
  if gui.is_running:
    log.info('Status check requested.')
    validate_input_status()
    build_cmds()
    #check_status(None)

with gui.abort:
  if gui.is_running:
    log.info('Abort requested.')
    validate_input_abort()
    build_cmds()
    abort_all()
    #check_status(None)

with gui.skip:
  if gui.is_running:
    log.debug('Skip status=%s' % gui.skip.isChecked())
    if gui.skip.isChecked():
      QMessageBox.warning(None, "Warning", "Skipping setup may break things, make sure you know what you are doing!")

with gui.keep:
  if gui.is_running:
    log.debug('Keep status=%s' % gui.keep.isChecked())

# Max does not seem to work, so we'll have to normalize to a percentage...
#gui.progress.minimum = 0
#gui.progress.maximum = 3
#gui.widgets['progress'].setFormat('%v/%m steps')

signal.signal(signal.SIGINT, handle_sigint)
set_defaults()
load_state()
gui.timer_start(check_status, 1)
gui.run()
