# ADOGRC Docker Compose Deployment Example

This repository contains sample Docker Compose artifacts for deploying ADOGRC 15.0.0 in customer-managed infrastructure.

## Files

- `docker-compose.yml` - Docker Compose definition for deploying ADOGRC with an existing external database.
- `.env.example` - Template file for environment-specific configuration values.

## Prerequisites

- Docker Engine and the Docker Compose plugin are installed.
- An external database is created and prepared for ADOGRC (see the DB creation guide below for setup details).

## Official Documentation

- ADOGRC 15.0 Database Setup Guide: [https://docs.boc-group.com/adogrc/en/docs/15.0/installation_manual/ins-4000001/](https://docs.boc-group.com/adogrc/en/docs/15.0/installation_manual/ins-4000001/)
- ADOGRC 15.0 Upgrade Guide: [https://docs.boc-group.com/adogrc/en/docs/15.0/installation_manual/ins-6000000/](https://docs.boc-group.com/adogrc/en/docs/15.0/installation_manual/ins-6000000/)
- ADOGRC 15.0 Installation Manual: [https://docs.boc-group.com/adogrc/en/docs/15.0/installation_manual/](https://docs.boc-group.com/adogrc/en/docs/15.0/installation_manual/)