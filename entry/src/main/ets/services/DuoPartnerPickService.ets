export interface DuoPartnerPick {
  target: string;
  name: string;
}

let pendingPick: DuoPartnerPick | undefined;

export function stageDuoPartnerPick(target: string, name: string): void {
  pendingPick = { target, name };
}

export function takeDuoPartnerPick(): DuoPartnerPick | undefined {
  const pick = pendingPick;
  pendingPick = undefined;
  return pick;
}
