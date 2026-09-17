/**
 * Typed API client for KORKEM Web Workspace and Public Portal.
 * Wraps Frappe / ERPNext REST endpoints with session cookie support (sid).
 */

export interface CompanyDetails {
  name?: string;
  company_name?: string;
  owner_name?: string;
  abbr?: string;
  bin?: string;
  tax_id?: string;
  phone?: string;
  email?: string;
  website?: string;
  address?: string;
  city?: string;
  bank_name?: string;
  bank_account?: string;
  bik?: string;
  currency?: string;
  default_currency?: string;
  country?: string;
}

export interface WarehouseItem {
  warehouse?: string;
  name: string;
  warehouse_name?: string;
  company?: string;
  is_group?: boolean;
  disabled?: boolean;
  positions?: number;
  is_shipping_default?: boolean;
}

export type Warehouse = WarehouseItem;

export interface StaffMember {
  user: string;
  email?: string;
  full_name?: string;
  first_name?: string;
  last_name?: string;
  position?: string;
  role?: string;
  designation?: string;
  status?: string;
  enabled?: boolean;
  roles?: string[];
}

export type TeamMember = StaffMember;

export interface PositionOption {
  position: string;
  roles: string[];
}

export class KorkemApiError extends Error {
  constructor(message: string, public status?: number, public details?: any) {
    super(message);
    this.name = 'KorkemApiError';
  }
}

async function request<T>(path: string, options: RequestInit = {}): Promise<T> {
  const headers = new Headers(options.headers || {});
  if (!headers.has('Content-Type') && options.body) {
    headers.set('Content-Type', 'application/json');
  }
  headers.set('Accept', 'application/json');

  const res = await fetch(path, {
    ...options,
    headers,
    credentials: 'include', // Ensures sid session cookie is forwarded
  });

  if (res.status === 401 || res.status === 403) {
    let msg = 'Необходима авторизация';
    try {
      const errJson = await res.json();
      if (errJson._server_messages) {
        const msgs = JSON.parse(errJson._server_messages);
        msg = msgs.map((m: any) => JSON.parse(m).message).join('; ');
      } else if (errJson.message) {
        msg = typeof errJson.message === 'string' ? errJson.message : JSON.stringify(errJson.message);
      }
    } catch {
      // ignore
    }
    throw new KorkemApiError(msg, res.status);
  }

  const contentType = res.headers.get('content-type') || '';
  if (!contentType.includes('application/json')) {
    if (!res.ok) {
      throw new KorkemApiError(`HTTP ${res.status}: ${res.statusText}`, res.status);
    }
    return {} as T;
  }

  const data = await res.json();

  if (!res.ok) {
    let errorMsg = `HTTP ${res.status}: ${res.statusText}`;
    if (data._server_messages) {
      try {
        const msgs = JSON.parse(data._server_messages);
        errorMsg = msgs.map((m: any) => JSON.parse(m).message).join('; ');
      } catch {
        // use default
      }
    } else if (data.message) {
      errorMsg = typeof data.message === 'string' ? data.message : JSON.stringify(data.message);
    } else if (data.exc) {
      errorMsg = 'Внутренняя ошибка сервера ERPNext';
    }
    throw new KorkemApiError(errorMsg, res.status, data);
  }

  if (data && typeof data === 'object' && 'message' in data) {
    return data.message as T;
  }

  return data as T;
}

export const korkemApi = {
  // Auth
  async login(usr: string, pwd: string): Promise<{ full_name: string; home_page: string }> {
    const res = await request<{ message?: string; full_name?: string; home_page?: string }>(
      '/api/method/login',
      {
        method: 'POST',
        body: JSON.stringify({ usr: usr.trim(), pwd }),
      }
    );
    return {
      full_name: (res as any)?.full_name || usr,
      home_page: (res as any)?.home_page || 'desk',
    };
  },

  async register(params: {
    company_name: string;
    owner_name: string;
    email: string;
    password: string;
    phone?: string;
  }): Promise<{ status: string; company: string; email: string }> {
    return request<{ status: string; company: string; email: string }>(
      '/api/method/korkem_manufacturing.api.registration.register',
      {
        method: 'POST',
        body: JSON.stringify({
          company_name: params.company_name.trim(),
          owner_name: params.owner_name.trim(),
          email: params.email.trim(),
          password: params.password,
          phone: (params.phone || '').trim(),
        }),
      }
    );
  },

  async logout(): Promise<void> {
    try {
      await request('/api/method/logout', { method: 'POST' });
    } catch {
      // Ignored on logout
    }
  },

  async getLoggedUser(): Promise<string | null> {
    try {
      const user = await request<string>('/api/method/frappe.auth.get_logged_user');
      if (!user || user === 'Guest') return null;
      return user;
    } catch {
      return null;
    }
  },

  // Company Details
  async getCompanyDetails(): Promise<CompanyDetails> {
    const res = await request<CompanyDetails>(
      '/api/method/korkem_manufacturing.api.company_details.read'
    );
    return res || {};
  },

  async saveCompanyDetails(details: Partial<CompanyDetails>): Promise<CompanyDetails> {
    return request<CompanyDetails>(
      '/api/method/korkem_manufacturing.api.company_details.save',
      {
        method: 'POST',
        body: JSON.stringify(details),
      }
    );
  },

  // Warehouses
  async getWarehouses(): Promise<WarehouseItem[]> {
    const list = await request<WarehouseItem[]>(
      '/api/method/korkem_manufacturing.api.warehouses.listing'
    );
    return Array.isArray(list) ? list : [];
  },

  async createWarehouse(input: string | { warehouse_name: string; parent_warehouse?: string }): Promise<{ status: string; warehouse: string }> {
    const payload = typeof input === 'string' ? { name: input.trim() } : { name: input.warehouse_name.trim() };
    return request<{ status: string; warehouse: string }>(
      '/api/method/korkem_manufacturing.api.warehouses.create',
      {
        method: 'POST',
        body: JSON.stringify(payload),
      }
    );
  },

  async setShippingDefault(warehouse: string): Promise<{ status: string }> {
    return request<{ status: string }>(
      '/api/method/korkem_manufacturing.api.warehouses.set_shipping_default',
      {
        method: 'POST',
        body: JSON.stringify({ warehouse }),
      }
    );
  },

  async setWarehouseDisabled(
    warehouse: string,
    disabled: boolean
  ): Promise<{ status: string }> {
    return request<{ status: string }>(
      '/api/method/korkem_manufacturing.api.warehouses.set_disabled',
      {
        method: 'POST',
        body: JSON.stringify({ warehouse, disabled: disabled ? 1 : 0 }),
      }
    );
  },

  // Team & Staff
  async getStaffMembers(): Promise<StaffMember[]> {
    const members = await request<StaffMember[]>(
      '/api/method/korkem_manufacturing.api.staff.members'
    );
    return Array.isArray(members) ? members : [];
  },

  async getTeamMembers(): Promise<StaffMember[]> {
    return this.getStaffMembers();
  },

  async canInvite(): Promise<boolean> {
    try {
      const res = await request<boolean>(
        '/api/method/korkem_manufacturing.api.staff.can_invite'
      );
      return Boolean(res);
    } catch {
      return false;
    }
  },

  async getPositions(): Promise<PositionOption[]> {
    const positions = await request<PositionOption[]>(
      '/api/method/korkem_manufacturing.api.invitations.positions'
    );
    return Array.isArray(positions) ? positions : [];
  },

  async inviteEmployee(params: {
    email: string;
    position: string;
    first_name?: string;
  }): Promise<{ status: string; user?: string }> {
    return request<{ status: string; user?: string }>(
      '/api/method/korkem_manufacturing.api.invitations.invite',
      {
        method: 'POST',
        body: JSON.stringify({
          email: params.email.trim(),
          position: params.position,
          first_name: (params.first_name || '').trim(),
        }),
      }
    );
  },

  async inviteMember(params: {
    email: string;
    position: string;
    first_name?: string;
  }): Promise<{ status: string; user?: string }> {
    return this.inviteEmployee(params);
  },

  async changePosition(
    email: string,
    position: string
  ): Promise<{ status: string }> {
    return request<{ status: string }>(
      '/api/method/korkem_manufacturing.api.staff.change_position',
      {
        method: 'POST',
        body: JSON.stringify({ email: email.trim(), position }),
      }
    );
  },

  async deactivateStaff(email: string): Promise<{ status: string }> {
    return request<{ status: string }>(
      '/api/method/korkem_manufacturing.api.staff.deactivate',
      {
        method: 'POST',
        body: JSON.stringify({ email: email.trim() }),
      }
    );
  },

  async deactivateMember(email: string): Promise<{ status: string }> {
    return this.deactivateStaff(email);
  },

  async reactivateStaff(email: string): Promise<{ status: string }> {
    return request<{ status: string }>(
      '/api/method/korkem_manufacturing.api.staff.reactivate',
      {
        method: 'POST',
        body: JSON.stringify({ email: email.trim() }),
      }
    );
  },

  async reactivateMember(email: string): Promise<{ status: string }> {
    return this.reactivateStaff(email);
  },

  // Invitations & Onboarding
  async getInvitationInfo(token: string): Promise<{
    valid: boolean;
    invitation_id?: string;
    company_name?: string;
    company_logo?: string;
    role_name?: string;
    role_title_ru?: string;
    role_title_kz?: string;
    desc_ru?: string;
    desc_kz?: string;
    landing_route?: string;
    invited_by?: string;
    phone?: string;
    expires_at?: string;
    short_code?: string;
    status?: string;
    error?: string;
  }> {
    return request(
      `/api/method/korkem_manufacturing.api.invitations.get_info?token=${encodeURIComponent(token)}`
    );
  },

  async acceptInvitation(params: {
    token: string;
    phone: string;
    full_name: string;
    email?: string;
    password?: string;
  }): Promise<{
    status: string;
    user: string;
    phone: string;
    full_name: string;
    company: string;
    role_name: string;
    role_title_ru: string;
    role_title_kz: string;
    landing_route: string;
    message: string;
  }> {
    return request(
      '/api/method/korkem_manufacturing.api.invitations.accept',
      {
        method: 'POST',
        body: JSON.stringify(params),
      }
    );
  },

  async createInvitation(params: {
    role_name: string;
    phone?: string;
    max_uses?: number;
    expires_days?: number;
    company?: string;
  }): Promise<{
    status: string;
    invitation_id: string;
    token: string;
    invite_url: string;
    short_code: string;
    company: string;
    role_name: string;
    role_title_ru: string;
    role_title_kz: string;
    landing_route: string;
    expires_at: string;
    share_text_kz: string;
    share_text_ru: string;
    whatsapp_url_kz: string;
    whatsapp_url_ru: string;
    telegram_url_kz: string;
    telegram_url_ru: string;
  }> {
    return request(
      '/api/method/korkem_manufacturing.api.invitations.create',
      {
        method: 'POST',
        body: JSON.stringify(params),
      }
    );
  },

  async revokeInvitation(invitation_id: string): Promise<{ status: string }> {
    return request(
      '/api/method/korkem_manufacturing.api.invitations.revoke',
      {
        method: 'POST',
        body: JSON.stringify({ invitation_id }),
      }
    );
  },

  async resendInvitation(invitation_id: string): Promise<{
    status: string;
    invitation_id: string;
    token: string;
    invite_url: string;
    role_name: string;
    role_title_ru: string;
    role_title_kz: string;
    share_text_kz: string;
    share_text_ru: string;
    whatsapp_url_kz: string;
    whatsapp_url_ru: string;
    telegram_url_kz: string;
    telegram_url_ru: string;
  }> {
    return request(
      '/api/method/korkem_manufacturing.api.invitations.resend',
      {
        method: 'POST',
        body: JSON.stringify({ invitation_id }),
      }
    );
  },

  async changeInvitationRole(invitation_id: string, new_role: string): Promise<{ status: string }> {
    return request(
      '/api/method/korkem_manufacturing.api.invitations.change_role',
      {
        method: 'POST',
        body: JSON.stringify({ invitation_id, new_role }),
      }
    );
  },

  async listInvitations(company?: string): Promise<Array<{
    id: string;
    role_name: string;
    role_title_ru: string;
    role_title_kz: string;
    invited_by: string;
    phone: string;
    expires_at: string;
    status: string;
    created_at: string;
    accepted_at?: string;
    accepted_by?: string;
  }>> {
    const query = company ? `?company=${encodeURIComponent(company)}` : '';
    const res = await request<any>(`/api/method/korkem_manufacturing.api.invitations.list_all${query}`);
    return Array.isArray(res) ? res : [];
  },

  async getCanonicalRoles(): Promise<Array<{
    key: string;
    title_ru: string;
    title_kz: string;
    desc_ru: string;
    desc_kz: string;
    landing_route: string;
    roles: string[];
  }>> {
    const res = await request<any>('/api/method/korkem_manufacturing.api.invitations.canonical_roles');
    return Array.isArray(res) ? res : [];
  },

  async requestOtp(phone: string): Promise<{
    status: string;
    phone: string;
    session_id: string;
    expires_in: number;
    dev_code?: string;
    message: string;
  }> {
    return request(
      '/api/method/korkem_manufacturing.api.registration.request_otp',
      {
        method: 'POST',
        body: JSON.stringify({ phone }),
      }
    );
  },

  async verifyOtp(phone: string, code: string, session_id?: string): Promise<{
    status: string;
    verified: boolean;
    phone: string;
    verification_token: string;
    message: string;
  }> {
    return request(
      '/api/method/korkem_manufacturing.api.registration.verify_otp',
      {
        method: 'POST',
        body: JSON.stringify({ phone, code, session_id }),
      }
    );
  },
};
