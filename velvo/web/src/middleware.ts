// porta de entrada opcional. se STUDIO_ACCESS_CODE estiver definido na vercel,
// /studio e as apis exigem basic auth (qualquer usuário + a senha = o código).
// se a env não existir, o site fica aberto. nada disso expõe a service role.
import { NextRequest, NextResponse } from "next/server";

export const config = {
  matcher: ["/studio/:path*", "/api/curator/:path*"],
};

export function middleware(req: NextRequest) {
  const code = process.env.STUDIO_ACCESS_CODE;
  if (!code) return NextResponse.next();

  const header = req.headers.get("authorization") || "";
  if (header.startsWith("Basic ")) {
    try {
      const decoded = atob(header.slice(6));
      const pass = decoded.split(":").slice(1).join(":");
      if (pass === code) return NextResponse.next();
    } catch {
      /* cai no 401 */
    }
  }
  return new NextResponse("acesso restrito", {
    status: 401,
    headers: { "www-authenticate": 'Basic realm="velvo studio"' },
  });
}
