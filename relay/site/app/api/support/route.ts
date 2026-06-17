export async function POST(request: Request) {
  try {
    const body = await request.json();
    const { name, email, message, issueType, priority } = body;

    if (!name?.trim() || !email?.trim() || !message?.trim()) {
      return Response.json({ ok: false, error: "Required fields missing" }, { status: 400 });
    }

    if (typeof message === "string" && message.length > 5000) {
      return Response.json({ ok: false, error: "Message too long" }, { status: 400 });
    }

    const ticketId = `ALLERAL-2026-${String(Math.floor(1000 + Math.random() * 9000))}`;

    return Response.json({
      ok: true,
      ticketId,
      message: "Ticket created successfully",
    });
  } catch {
    return Response.json({ ok: false, error: "Invalid request" }, { status: 400 });
  }
}
