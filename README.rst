.. image:: https://travis-ci.org/bibi21000/janitoo_mosquitto.svg?branch=master
    :target: https://travis-ci.org/bibi21000/janitoo_mosquitto
    :alt: Travis status

.. image:: https://img.shields.io/badge/Documentation-ok-brightgreen.svg?style=flat
   :target: https://bibi21000.github.io/janitoo_mosquitto/index.html
   :alt: Documentation

============================
Welcome to janitoo_mosquitto
============================

As we need websockets support, we must install a recent version of mosquitto.

This is the job of this module. It installs packages for Debian, Ubuntu and Raspdebian using method listed here : http://mosquitto.org/download/

Configuration
=============

Websockets are listen on all addresses on port 9001. This is not secure.

We must use https://www.nginx.com/blog/websocket-nginx/ in production.

mqtt is on 1883.

Documentation
=============
You can browse online documentation here : https://bibi21000.github.io/janitoo_mosquitto/.

Tutorial
========
You can find a tutorial here : https://bibi21000.github.io/janitoo_tutorial/.
