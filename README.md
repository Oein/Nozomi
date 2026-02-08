# Nozomi

대충대충 바이브 코딩한 링크 단축기

## Behavior

- `/` redirects to `https://blog.oein.kr`
- `/:id` redirects to the stored target URL
- Unknown ids (and other unknown routes) show a “Link not found” page
- Admin UI lives at `/_oein` and is protected with HTTP Basic Auth via `ADMIN_PASSWORD`

## Admin

The admin page supports:

- Create with **custom id**
- Create with **random id** using alphabet `qwertyupasdfghjkzxcvbnm23456789`
  - Starts at length 3
  - If all ids of a given length are used, it automatically moves to the next length
- Manage links: list / edit id / edit target / delete

### Auth

Set `ADMIN_PASSWORD` in `.env`.

The admin endpoints are:

- UI: `/_oein/*`
- API: `/api/_oein/*`

Your browser will prompt for Basic Auth. Any username works; the password must match `ADMIN_PASSWORD`.

To install dependencies:

```bash
bun install
```

To run:

```bash
bun run index.ts
```

## Environment

Create a `.env` file:

```dotenv
DATABASE_URL="file:./dev.db"
ADMIN_PASSWORD="your-password"
PORT=3000
```

## Deploy helpers

### Prisma postrun

Runs migrations (deploy) and regenerates Prisma client:

```bash
bun run postrun
```

### Alpine (OpenRC)

Registers the app as an OpenRC service:

```bash
sudo sh scripts/register-alpine-openrc.sh /opt/link-shorten linkshorten
sudo rc-service link-shorten start
```

This project was created using `bun init` in bun v1.2.20. [Bun](https://bun.com) is a fast all-in-one JavaScript runtime.
