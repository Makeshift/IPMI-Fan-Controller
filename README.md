# IPMI-Fan-Controller

This is a little service that uses IPMI to manage fan speeds based on the temperature of the CPU.

This was designed for an R710 running iDrac6 (which doesn't have fan curve control!), but should be fairly adaptable.

# Installation

I chose to use `/opt` here just becaue it makes the paths in `ipmi_fan_controller.service` simpler. You can clone it to anywhere as long as you update the paths in that file.

```
sudo git clone https://github.com/Makeshift/IPMI-Fan-Controller.git
sudo chown -R $USER:$USER IPMI-Fan-Controller
cd IPMI-Fan-Controller
sudo cp ipmi_fan_controller.service /etc/systemd/system/
# Modify /opt/IPMI-Fan-Controller/config.conf to your liking
sudo systemctl daemon-reload
sudo systemctl enable ipmi_fan_controller.service
sudo systemctl start ipmi_fan_controller.service
sudo journalctl -fu ipmi_fan_controller.service
```
