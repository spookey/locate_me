locate me
=========

This script reads NMEA Strings from an USB-Serial GPS Dongle,
and writes the position data into the ``/etc/config/gluon-node-info`` file.

It is intended to run directly on a Freifunk Router, running `Gluon <https://github.com/freifunk-gluon/gluon>`_ Firmware and has an USB Socket.

Initial version was written using a Navilock NL-601US.

* `lua uci reference <http://luci.subsignal.org/api/luci/modules/luci.model.uci.html>`_

installation
------------

You need drivers for your USB-Serial GPS Dongle.

Check ``ls /dev/`` for any ``ttyUSB*`` device, try ``dmesg`` and ``logread``
to find any signs of your hardware.

Install via ``opkg``::

    opkg update
    opkg install kmod-usb-acm


Use the ``copy_run.sh`` script to copy, and then run your scripts on a node.
