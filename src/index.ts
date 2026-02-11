import "dotenv/config";

import express, { type NextFunction, type Request, type Response } from "express";
import path from "node:path";
import crypto from "node:crypto";
import { fileURLToPath } from "node:url";

import { prisma } from "./db";
import { Prisma } from "./generated/prisma/client";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const PROJECT_ROOT = path.resolve(__dirname, "..");
const ADMIN_PUBLIC_DIR = path.join(PROJECT_ROOT, "public", "_oein");
const NOT_FOUND_FILE = path.join(PROJECT_ROOT, "public", "not-found.html");

const RANDOM_ALPHABET = "qwertyupasdfghjkzxcvbnm23456789";
const DEFAULT_RANDOM_LENGTH = 3;

function parseBasicAuth(req: Request): { username: string; password: string } | null {
    const header = req.header("authorization");
    if (!header) return null;

    const [scheme, token] = header.split(" ");
    if (scheme !== "Basic" || !token) return null;

    let decoded = "";
    try {
        decoded = Buffer.from(token, "base64").toString("utf8");
    } catch {
        return null;
    }

    const idx = decoded.indexOf(":");
    if (idx < 0) return null;
    return {
        username: decoded.slice(0, idx),
        password: decoded.slice(idx + 1),
    };
}

function adminAuth(req: Request, res: Response, next: NextFunction) {
    const expected = process.env.ADMIN_PASSWORD;
    if (!expected) {
        res.status(500).send("ADMIN_PASSWORD is not configured");
        return;
    }

    const creds = parseBasicAuth(req);
    if (!creds || creds.password !== expected) {
        res.setHeader("WWW-Authenticate", 'Basic realm="Admin"');
        res.status(401).send("Unauthorized");
        return;
    }

    next();
}

function isSafeShortId(id: unknown): id is string {
    return (
        typeof id === "string" &&
        id.length > 0 &&
        id.length <= 128 &&
        !id.includes("/") &&
        !id.includes("\\") &&
        !/\s/.test(id)
    );
}

function isValidTargetUrl(value: unknown): value is string {
    if (typeof value !== "string") return false;
    try {
        const url = new URL(value);
        return url.protocol === "http:" || url.protocol === "https:";
    } catch {
        return false;
    }
}

function sendNotFound(res: Response) {
    res.status(404).sendFile(NOT_FOUND_FILE, (err) => {
        if (err) {
            res.status(404).type("text").send("Link not found");
        }
    });
}

function randomId(length: number) {
    let out = "";
    for (let i = 0; i < length; i++) {
        const idx = crypto.randomInt(0, RANDOM_ALPHABET.length);
        out += RANDOM_ALPHABET[idx] ?? "";
    }
    return out;
}

function capacityForLength(length: number): bigint {
    return BigInt(RANDOM_ALPHABET.length) ** BigInt(length);
}

async function usedCountForLength(length: number): Promise<number> {
    const rows = await prisma.$queryRaw<Array<{ count: number }>>`
		SELECT COUNT(*) as count FROM "Link" WHERE length(id) = ${length}
	`;
    return rows[0]?.count ?? 0;
}

async function createRandomLink(targetUrl: string) {
    let length = DEFAULT_RANDOM_LENGTH;
    while (true) {
        const used = await usedCountForLength(length);
        const capacity = capacityForLength(length);
        if (capacity <= BigInt(Number.MAX_SAFE_INTEGER) && BigInt(used) >= capacity) {
            length += 1;
            continue;
        }

        for (let attempt = 0; attempt < 80; attempt++) {
            const id = randomId(length);
            try {
                return await prisma.link.create({ data: { id, targetUrl } });
            } catch (err: any) {
                if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === "P2002") {
                    continue;
                }
                throw err;
            }
        }

        length += 1;
    }
}

export async function startServer() {
    const app = express();
    app.disable("x-powered-by");

    app.use("/_oein", adminAuth, express.static(ADMIN_PUBLIC_DIR));

    app.use("/api/_oein", adminAuth, express.json());

    app.get("/api/_oein/links", async (req, res) => {
        const pageRaw = typeof req.query.page === "string" ? req.query.page : undefined;
        const pageSizeRaw =
            typeof req.query.pageSize === "string" ? req.query.pageSize : undefined;

        const page = Math.max(1, Number(pageRaw ?? 1) || 1);
        const pageSize = Math.min(200, Math.max(1, Number(pageSizeRaw ?? 50) || 50));

        const total = await prisma.link.count();
        const totalPages = Math.max(1, Math.ceil(total / pageSize));
        const safePage = Math.min(page, totalPages);

        const links = await prisma.link.findMany({
            orderBy: { createdAt: "desc" },
            skip: (safePage - 1) * pageSize,
            take: pageSize,
        });

        res.json({
            links,
            page: safePage,
            pageSize,
            total,
            totalPages,
        });
    });

    app.post("/api/_oein/links", async (req, res) => {
        const { mode, id, targetUrl } = (req.body ?? {}) as {
            mode?: "custom" | "random";
            id?: unknown;
            targetUrl?: unknown;
        };

        if (!isValidTargetUrl(targetUrl)) {
            res.status(400).json({ error: "targetUrl must be a valid http(s) URL" });
            return;
        }

        if (mode === "random") {
            const link = await createRandomLink(targetUrl);
            res.status(201).json({ link });
            return;
        }

        if (!isSafeShortId(id)) {
            res.status(400).json({ error: "id is required for custom mode" });
            return;
        }

        try {
            const link = await prisma.link.create({ data: { id, targetUrl } });
            res.status(201).json({ link });
        } catch (err: any) {
            if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === "P2002") {
                res.status(409).json({ error: "id already exists" });
                return;
            }
            throw err;
        }
    });

    app.patch("/api/_oein/links/:id", async (req, res) => {
        const currentId = req.params.id;
        const { newId, targetUrl } = (req.body ?? {}) as { newId?: unknown; targetUrl?: unknown };

        if (newId !== undefined && !isSafeShortId(newId)) {
            res.status(400).json({ error: "newId is invalid" });
            return;
        }
        if (targetUrl !== undefined && !isValidTargetUrl(targetUrl)) {
            res.status(400).json({ error: "targetUrl must be a valid http(s) URL" });
            return;
        }
        if (newId === undefined && targetUrl === undefined) {
            res.status(400).json({ error: "nothing to update" });
            return;
        }

        try {
            const link = await prisma.link.update({
                where: { id: currentId },
                data: {
                    ...(newId !== undefined ? { id: newId } : {}),
                    ...(targetUrl !== undefined ? { targetUrl } : {}),
                },
            });
            res.json({ link });
        } catch (err: any) {
            if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === "P2025") {
                res.status(404).json({ error: "link not found" });
                return;
            }
            if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === "P2002") {
                res.status(409).json({ error: "newId already exists" });
                return;
            }
            throw err;
        }
    });

    app.delete("/api/_oein/links/:id", async (req, res) => {
        const id = req.params.id;
        try {
            await prisma.link.delete({ where: { id } });
            res.status(204).end();
        } catch (err: any) {
            if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === "P2025") {
                res.status(404).json({ error: "link not found" });
                return;
            }
            throw err;
        }
    });

    app.get("/:id", async (req, res) => {
        const id = req.params.id;
        const link = await prisma.link.findUnique({ where: { id } });
        if (!link) {
            sendNotFound(res);
            return;
        }
        res.redirect(302, link.targetUrl);
    });

    app.use((_req, res) => {
        sendNotFound(res);
    });

    const port = Number(process.env.PORT ?? 3000);
    app.listen(port, () => {
        // eslint-disable-next-line no-console
        console.log(`link-shorten listening on http://localhost:${port}`);
    });

    const shutdown = async () => {
        await prisma.$disconnect();
        process.exit(0);
    };

    process.on("SIGINT", shutdown);
    process.on("SIGTERM", shutdown);
}

if (import.meta.main) {
    void startServer();
}
