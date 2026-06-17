"use client";

import type { SitePayload } from "@/lib/types";
import { Panel } from "@/components/ui/Panel";

export function CreditsView({ site }: { site: SitePayload }) {
  const credits = site.credits;
  if (!credits) return <p className="text-muted">Credits unavailable.</p>;

  return (
    <div className="space-y-8">
      <Panel padding="md">
        <h2 className="text-xl font-semibold">{credits.headline || "Team"}</h2>
        {credits.subheadline ? <p className="mt-2 text-sm text-muted">{credits.subheadline}</p> : null}
      </Panel>
      {(credits.teams || []).map((team) => (
        <div key={team.id || team.title}>
          <h3 className="mb-4 text-lg font-semibold">{team.title}</h3>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {(team.members || []).map((member) => (
              <Panel
                key={member.id || member.displayName}
                padding="md"
                hover
                glow={!!member.accent}
                style={member.accent ? { boxShadow: `0 0 0 1px ${member.accent}33 inset` } : undefined}
              >
                <strong className="block text-lg">{member.displayName}</strong>
                <span className="text-sm text-accent">{member.role}</span>
                {member.bio ? <p className="mt-3 text-sm text-muted">{member.bio}</p> : null}
              </Panel>
            ))}
          </div>
        </div>
      ))}
    </div>
  );
}
