# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added
- Initial release of BirdNET-ODAS integration
- ReSpeaker USB 4 Mic Array support
- Log-MMSE noise suppression algorithm
- ALSA loopback audio pipeline
- Automated installation scripts for Raspberry Pi and NanoPi
- Systemd services for auto-start and monitoring
- Pipeline healthcheck with automatic USB recovery
- Comprehensive documentation

### Changed
- Optimized audio buffer settings (32768/8192)
- Improved MIN_GAIN for better signal processing (0.15)
- Enhanced USB autosuspend handling
- Updated BirdNET-Go to nightly builds

### Fixed
- USB autosuspend causing device disconnections
- Audio pipeline underruns
- Docker container conflicts with systemd
- Network DHCP issues on NanoPi

## [1.0.0] - Initial Release

### Core Features
- BirdNET-Go integration with Docker
- ReSpeaker 4 Mic Array audio capture
- Real-time audio processing pipeline
- Web interface for monitoring
- MQTT integration for Home Assistant
- Automatic clip retention management
- Geographic species filtering
- Multi-platform support (Raspberry Pi, NanoPi)

### Documentation
- Installation guide
- Configuration guide
- Troubleshooting guide
- Audio pipeline technical documentation
- Platform-specific setup guides

---

For detailed information about each version, see the [documentation](docs/).
