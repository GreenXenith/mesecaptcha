#!/bin/bash

convert -size 252x8 xc:white -fill black -font DejaVu-Sans-Mono-Bold -pointsize 11 -annotate +0+8 "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ" captcha_alphabet.png
