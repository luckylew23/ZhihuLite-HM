/**
 * 赞同/投票相关 API —— 移植自上游 zhihu--/api/zhihu/voters.ts。
 * 覆盖：回答/想法的赞同用户列表、内容投票（赞/踩/喜欢/取消）。
 * 改动：
 *   · axios(baseURL=…/api/v4) → zhihuClient 绝对 URL
 *   · 对象体 → JSON.stringify + application/json
 *   · 去掉接口上的索引签名，改为具体字段
 */

import { zhihuClient } from './httpClient';

const API_V4 = 'https://www.zhihu.com/api/v4';

const JSON_HEADERS: Record<string, string> = {
  'Content-Type': 'application/json;charset=utf-8',
};

export interface ZhihuApiErrorDetail {
  code: number;
  name: string;
  message: string;
}

export interface ZhihuErrorResponse {
  error: ZhihuApiErrorDetail;
}

export interface ZhihuVoteResponse {
  success?: boolean;
}

export interface ZhihuVoter {
  id: string;
  url_token?: string;
  name: string;
  avatar_url?: string;
  headline?: string;
  is_following?: boolean;
}

export interface ZhihuVotersPaging {
  is_end?: boolean;
  next?: string;
}

export interface ZhihuVotersResponse {
  data: ZhihuVoter[];
  paging?: ZhihuVotersPaging;
}

/** 回答的赞同用户列表 */
export const getAnswerVoters = async (
  id: string | number,
  limit: number = 20,
  offset: number = 0,
): Promise<ZhihuVotersResponse> => {
  const res = await zhihuClient.get<ZhihuVotersResponse>(
    API_V4 + '/answers/' + encodeURIComponent(String(id)) +
      '/upvoters?limit=' + String(limit) + '&offset=' + String(offset),
  );
  return res.data;
};

/** 想法的赞同用户列表 */
export const getPinVoters = async (
  id: string | number,
  limit: number = 20,
  offset: number = 0,
): Promise<ZhihuVotersResponse> => {
  const res = await zhihuClient.get<ZhihuVotersResponse>(
    API_V4 + '/pins/' + encodeURIComponent(String(id)) +
      '/upvoters?limit=' + String(limit) + '&offset=' + String(offset),
  );
  return res.data;
};

/** 内容投票（赞/踩/喜欢/取消） */
export const voteContent = async (
  id: string | number,
  type: string,
  voteType: string,
): Promise<ZhihuVoteResponse> => {
  const encId = encodeURIComponent(String(id));

  if (type === 'pins') {
    if (voteType === 'like' || voteType === 'up') {
      const res = await zhihuClient.post<ZhihuVoteResponse>(
        API_V4 + '/pins/' + encId + '/voters/up',
        {
          headers: JSON_HEADERS,
          data: JSON.stringify({ not_sync_moments: true }),
        },
      );
      return res.data;
    }
    const cancelRes = await zhihuClient.delete<ZhihuVoteResponse>(
      API_V4 + '/pins/' + encId + '/voters/up',
    );
    return cancelRes.data;
  }

  if (type === 'comments') {
    if (voteType === 'up' || voteType === 'like') {
      const res = await zhihuClient.post<ZhihuVoteResponse>(
        API_V4 + '/comments/' + encId + '/like',
      );
      return res.data;
    }
    const cancelRes = await zhihuClient.delete<ZhihuVoteResponse>(
      API_V4 + '/comments/' + encId + '/like',
    );
    return cancelRes.data;
  }

  const res = await zhihuClient.post<ZhihuVoteResponse>(
    API_V4 + '/' + type + '/' + encId + '/voters',
    {
      headers: JSON_HEADERS,
      data: JSON.stringify({ type: voteType }),
    },
  );
  return res.data;
};
