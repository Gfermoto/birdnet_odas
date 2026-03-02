# Project Structure

```
birdnet_odas/
├── README.md                   # Main documentation
├── CHANGELOG.md               # Version history
├── article.md                 # Detailed article about the project
├── .gitignore                 # Git ignore rules
├── docker-compose.yml         # Docker configuration
├── env.example                # Environment variables template
│
├── docs/                      # Documentation
│   ├── README.md
│   ├── audio_pipeline.md      # Audio pipeline technical docs
│   ├── birdnet_go_setup.md    # BirdNET-Go configuration
│   ├── docker_compose_guide.md
│   ├── respeaker_usb4mic_setup.md  # ReSpeaker setup
│   ├── troubleshooting.md     # Problem solving guide
│   └── usb_isolator_power.md
│
├── scripts/                   # Utility scripts
│   ├── README.md
│   ├── check_audio_devices.sh        # Audio device diagnostics
│   ├── check_gain.sh                 # Gain monitoring
│   ├── collect_metrics.sh            # Performance metrics
│   ├── diagnose_clicks.sh            # Audio artifacts detection
│   ├── disable_led_ring.py           # LED control
│   ├── fix_birdnet_device.sh         # Device configuration fix
│   ├── fix_network_dhcp.sh           # DHCP troubleshooting
│   ├── install_metrics_service.sh    # Metrics service setup
│   ├── log_mmse_processor.py         # **Noise suppression (core)**
│   ├── optimize_performance.sh       # System optimizations
│   ├── respeaker-tune.sh             # **ReSpeaker DSP config (core)**
│   └── respeaker_loopback.sh         # **Audio pipeline (core)**
│
├── platforms/                 # Platform-specific setup
│   ├── raspberry-pi/
│   │   ├── README.md
│   │   ├── setup.sh                  # Automated installation
│   │   └── config.env
│   ├── nanopi-m4b/
│   │   ├── README.md
│   │   ├── setup.sh
│   │   └── config.env
│   └── common/
│       ├── setup_respeaker.sh        # ReSpeaker configuration
│       └── setup_audio_pipeline.sh   # Pipeline installation
│
├── images/                    # Documentation images
│   └── README.md
│
└── wav/                       # Test audio files
    └── (sample files)

## Core Components

### Essential Scripts (Production)
- `scripts/respeaker_loopback.sh` - Main audio pipeline
- `scripts/log_mmse_processor.py` - Noise suppression algorithm
- `scripts/respeaker-tune.sh` - DSP configuration

### Setup Scripts
- `platforms/*/setup.sh` - Automated platform-specific installation
- `platforms/common/setup_*.sh` - Shared setup components

### Utility Scripts (Development/Diagnostics)
- `scripts/check_*.sh` - Diagnostic tools
- `scripts/diagnose_*.sh` - Troubleshooting utilities
- `scripts/fix_*.sh` - Automated fixes

### System Integration
- `docker-compose.yml` - BirdNET-Go container configuration
- systemd services (installed by setup scripts):
  - `respeaker-loopback.service` - Audio pipeline
  - `respeaker-tune.service` - ReSpeaker DSP
  - `pipeline-healthcheck.service/timer` - Monitoring

## File Locations (After Installation)

### System Files
```
/usr/local/bin/
├── respeaker_loopback.sh
├── log_mmse_processor.py
└── respeaker-tune.sh

/etc/systemd/system/
├── respeaker-loopback.service
├── respeaker-tune.service
├── pipeline-healthcheck.service
└── pipeline-healthcheck.timer

/etc/udev/rules.d/
└── 99-respeaker.rules

/etc/modules-load.d/
└── snd-aloop.conf

/var/log/birdnet-pipeline/
├── errors.log
└── pipeline_stats.json
```

### Docker Volumes
```
/var/lib/docker/volumes/
└── birdnet-go-data/
    └── _data/
        ├── config.yaml
        ├── birdnet.db
        └── clips/
```

## Documentation Map

1. **Quick Start**: `README.md` → Platform-specific `setup.sh`
2. **Configuration**: `docs/birdnet_go_setup.md`, `docs/respeaker_usb4mic_setup.md`
3. **Troubleshooting**: `docs/troubleshooting.md`
4. **Deep Dive**: `article.md`, `docs/audio_pipeline.md`

## Development

### Testing Audio Pipeline
```bash
scripts/check_audio_devices.sh    # Check devices
scripts/check_gain.sh              # Verify gain settings
scripts/diagnose_clicks.sh         # Audio quality
```

### Performance Monitoring
```bash
scripts/collect_metrics.sh         # Collect metrics
cat /var/log/birdnet-pipeline/pipeline_stats.json
```

## Maintenance

### Regular Checks
- Disk space: `df -h`
- Service status: `systemctl status respeaker-loopback`
- Container health: `docker ps`
- Logs: `journalctl -fu respeaker-loopback`

### Updates
```bash
cd ~/birdnet_odas
git pull
docker compose pull
docker compose up -d
```

## Clean Repository

The project maintains a clean structure with:
- No temporary files in version control
- Proper `.gitignore` rules
- Clear separation of documentation, code, and platform configs
- Automated installation scripts for easy deployment
