#!/usr/bin/env bash
{ upower -d; upower --monitor-detail; } \
   | rg '\s*time to.*:\s*(\d.*)\s*$' -r '$1'
