# ADOIT Docker Compose Deployment Example

This repository contains sample Docker Compose artifacts for deploying ADOIT 21.0.0 in customer-managed infrastructure.

## Files

- `compose.yaml` - Docker Compose definition for deploying ADOIT with an existing external database.
- `.env.example` - Template file for environment-specific configuration values.

## Prerequisites

- Docker Engine and the Docker Compose plugin are installed.
- An external database is created and prepared for ADOIT (see the DB creation guide below for setup details).

## Official Documentations

- ADOIT 21.0 Technical Product Information: [https://docs.boc-group.com/adoit/en/adoit_21_technical_info/](https://docs.boc-group.com/adoit/en/adoit_21_technical_info/)
- ADOIT 21.0 Database Setup Guide: [https://docs.boc-group.com/adoit/en/docs/21.0/installation_manual/ins-4000001/](https://docs.boc-group.com/adoit/en/docs/21.0/installation_manual/ins-4000001/)
- ADOIT 21.0 Upgrade Guide: [https://docs.boc-group.com/adoit/en/docs/21.0/installation_manual/ins-6000000/](https://docs.boc-group.com/adoit/en/docs/21.0/installation_manual/ins-6000000/)
- ADOIT 21.0 Installation Manual: [https://docs.boc-group.com/adoit/en/docs/21.0/installation_manual/](https://docs.boc-group.com/adoit/en/docs/21.0/installation_manual/)