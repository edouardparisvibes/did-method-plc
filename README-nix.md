# Running DID PLC with Nix

This project includes a Nix flake for easy building and deployment.

## Quick Start

### Development Environment

Enter the development shell with all dependencies:

```bash
nix develop
```

This provides:
- Node.js and pnpm
- PostgreSQL 15
- Docker and docker-compose
- Development tools (git, curl, jq)

### Running the Server

1. **Start PostgreSQL** (using Docker):
   ```bash
   cd packages/server
   docker-compose -f pg/docker-compose.yaml up -d
   ```

2. **Set environment variables**:
   ```bash
   export DATABASE_URL='postgres://pg:password@localhost:5432/postgres'
   export PORT=3000
   ```

3. **Install dependencies and build**:
   ```bash
   pnpm install
   pnpm build
   ```

4. **Run the server**:
   ```bash
   pnpm --filter @did-plc/server start
   # or using nix
   nix run
   ```

### Building and Running

Build the server script:
```bash
nix build .#did-plc-server
```

This creates a script that builds and starts the server:
- `./result/bin/did-plc-server` - Build and start the server

### Using with direnv

If you have `direnv` installed, the `.envrc` file will automatically load the development environment when you enter the directory:

```bash
direnv allow
```

## Direct Usage

Run the server directly with Nix:
```bash
nix run .#did-plc-server
```

Or build the script first:
```bash
nix build .#did-plc-server
./result/bin/did-plc-server
```

## Environment Variables

- `PORT` - Server port (default: 3000)
- `DATABASE_URL` - PostgreSQL connection string
- `LOG_LEVEL` - Logging level (error, warn, info, debug)
- `NODE_ENV` - Node environment (development, production)

## Database Setup

The server requires PostgreSQL. For development:

```bash
cd packages/server
docker-compose -f pg/docker-compose.yaml up -d
export DATABASE_URL='postgres://pg:password@localhost:5432/postgres'
```

For production, set up a proper PostgreSQL instance and configure the `DATABASE_URL` accordingly.