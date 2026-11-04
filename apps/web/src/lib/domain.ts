import domain from "../../../../shared/domain.json";

export const product = domain;

export const consentVersion = domain.consentVersion;

export function isAdult(dateOfBirth: string, today = new Date()): boolean {
  if (!dateOfBirth) return false;
  const dob = new Date(`${dateOfBirth}T00:00:00`);
  if (Number.isNaN(dob.getTime())) return false;
  const cutoff = new Date(today.getFullYear() - domain.minimumAge, today.getMonth(), today.getDate());
  return dob <= cutoff;
}
