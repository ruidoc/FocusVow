import { OrgDetail, OrgLive, OrgRank, parseOrgDetail, parseOrgLive, parseOrgRank } from '../models/OrgModel';
import { ApiEnvelope } from '../models/UserModel';
import { StatsPeriod } from './StatsRecordUtil';
import { HttpService } from './HttpService';

export class OrgApiService {
  static async listMine(): Promise<ApiEnvelope> {
    return HttpService.get('/org/mine');
  }

  /** 公开组织 + 我的组织 */
  static async listDiscover(): Promise<ApiEnvelope> {
    return HttpService.get('/org/discover');
  }

  static async join(code: string): Promise<ApiEnvelope> {
    const body: Record<string, Object> = {
      'code': code
    };
    return HttpService.post('/org/join', body);
  }

  static async joinById(orgId: string): Promise<ApiEnvelope> {
    return HttpService.post(`/org/${encodeURIComponent(orgId)}/join`, {});
  }

  static async leave(orgId: string): Promise<ApiEnvelope> {
    return HttpService.post(`/org/${encodeURIComponent(orgId)}/leave`, {});
  }

  static async getDetail(orgId: string): Promise<ApiEnvelope> {
    return HttpService.get(`/org/${encodeURIComponent(orgId)}`);
  }

  static parseDetail(response: ApiEnvelope): OrgDetail | null {
    if (response.statusCode !== 200 || !response.data) {
      return null;
    }
    return parseOrgDetail(response.data);
  }

  static async getRank(orgId: string, period: StatsPeriod): Promise<ApiEnvelope> {
    const query: Record<string, string> = {
      'period': period
    };
    return HttpService.getWithQuery(`/org/${encodeURIComponent(orgId)}/rank`, query);
  }

  static parseRank(response: ApiEnvelope): OrgRank | null {
    if (response.statusCode !== 200 || !response.data) {
      return null;
    }
    return parseOrgRank(response.data);
  }

  static async getLive(orgId: string): Promise<ApiEnvelope> {
    return HttpService.get(`/org/${encodeURIComponent(orgId)}/live`);
  }

  static parseLive(response: ApiEnvelope): OrgLive {
    if (response.statusCode !== 200 || !response.data) {
      return { waiting: [], duo_active: [], solo_active: [] };
    }
    return parseOrgLive(response.data);
  }

  static async patchOrg(orgId: string, body: Record<string, Object>): Promise<ApiEnvelope> {
    return HttpService.patch(`/org/${encodeURIComponent(orgId)}`, body);
  }

  static async createClassroom(
    orgId: string,
    body: Record<string, Object>
  ): Promise<ApiEnvelope> {
    return HttpService.post(`/org/${encodeURIComponent(orgId)}/classroom`, body);
  }

  static async getActiveClassroom(orgId: string): Promise<ApiEnvelope> {
    return HttpService.get(`/org/${encodeURIComponent(orgId)}/classroom/active`);
  }

  static async joinClassroom(orgId: string, classroomId: string): Promise<ApiEnvelope> {
    return HttpService.post(
      `/org/${encodeURIComponent(orgId)}/classroom/${encodeURIComponent(classroomId)}/join`,
      {}
    );
  }

  static async startClassroom(
    orgId: string,
    classroomId: string,
    body: Record<string, Object>
  ): Promise<ApiEnvelope> {
    return HttpService.post(
      `/org/${encodeURIComponent(orgId)}/classroom/${encodeURIComponent(classroomId)}/start`,
      body
    );
  }

  static async endClassroom(orgId: string, classroomId: string): Promise<ApiEnvelope> {
    return HttpService.post(
      `/org/${encodeURIComponent(orgId)}/classroom/${encodeURIComponent(classroomId)}/end`,
      {}
    );
  }

  static async leaveClassroom(orgId: string, classroomId: string): Promise<ApiEnvelope> {
    return HttpService.post(
      `/org/${encodeURIComponent(orgId)}/classroom/${encodeURIComponent(classroomId)}/leave`,
      {}
    );
  }

  static async approveExitRequest(
    orgId: string,
    classroomId: string,
    requestId: string
  ): Promise<ApiEnvelope> {
    return HttpService.post(
      `/org/${encodeURIComponent(orgId)}/classroom/${encodeURIComponent(classroomId)}/exit-request/${encodeURIComponent(requestId)}/approve`,
      {}
    );
  }

  static async rejectExitRequest(
    orgId: string,
    classroomId: string,
    requestId: string
  ): Promise<ApiEnvelope> {
    return HttpService.post(
      `/org/${encodeURIComponent(orgId)}/classroom/${encodeURIComponent(classroomId)}/exit-request/${encodeURIComponent(requestId)}/reject`,
      {}
    );
  }
}
