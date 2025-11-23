#!/usr/bin/env bash
set -e
cd /root/usb_4_mic_array || exit 0
python3 tuning.py HPFONOFF 3
python3 tuning.py FREEZEONOFF 0
python3 tuning.py ECHOONOFF 0
python3 tuning.py AECONOFF 0
python3 tuning.py AECFREEZEONOFF 0
python3 tuning.py NLAEC_MODE 0
python3 tuning.py STATNOISEONOFF 1
python3 tuning.py NONSTATNOISEONOFF 1
python3 tuning.py TRANSIENTONOFF 1
python3 tuning.py GAMMA_NS_SR 2.5
python3 tuning.py GAMMA_NN_SR 1.1  # Не изменяется (firmware limitation)
python3 tuning.py MIN_NS_SR 0.1
python3 tuning.py MIN_NN_SR 0.1
python3 tuning.py AGCONOFF 1
python3 tuning.py AGCMAXGAIN 8.0
python3 tuning.py AGCDESIREDLEVEL 0.005
python3 tuning.py AGCTIME 0.1  # Минимальное значение для быстрой реакции на изменения в пении птиц (firmware преобразует в ~0.85 сек)
python3 tuning.py GAMMAVAD_SR 1000
