#!/bin/bash

for i in {0..9}; do
	convert -size 8x8 xc:white PNG32:'captcha_char_'$i'.png'
done

for i in {a..z}; do
	convert -size 8x8 xc:white PNG32:'captcha_char_'$i'.png'
done
