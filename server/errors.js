export class ValidationError extends Error {}
export class ConflictError extends Error {}
export class AuthenticationError extends Error {}
export class ForbiddenError extends Error {}
export class PasswordChangeRequiredError extends ForbiddenError {}
export class NotFoundError extends Error {}