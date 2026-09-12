/**
 * 知乎错误信息提取 —— 移植自上游 zhihu--/utils/zhihuError.ts。
 * 改动：unknown → object（ArkTS）。
 */

function isRecord(value: object): boolean {
  return typeof value === 'object' && value !== null;
}

export function getZhihuErrorMessage(error: object): string {
  if (isRecord(error) && isRecord((error as Record<string, object>)['response'])) {
    const response = (error as Record<string, object>)['response'] as Record<string, object>;
    const status = response['status'];
    const data = response['data'];
    if (isRecord(data) && isRecord(data['error'])) {
      const errorObj = data['error'] as Record<string, object>;
      const message = errorObj['message'];
      if (typeof message === 'string' && (message as string).length > 0) {
        return message as string;
      }
    }
    if (isRecord(data)) {
      const message = data['message'];
      if (typeof message === 'string' && (message as string).length > 0) {
        return message as string;
      }
    }
    if (typeof status === 'number') {
      const s = status as number;
      if (s === 400) return '请求参数无效，请检查后重试';
      if (s === 401) return '登录状态已失效，请重新登录';
      if (s === 403) return '当前账号没有执行此操作的权限';
      if (s === 404) return '请求的内容不存在或已被删除';
      if (s === 408) return '请求超时，请稍后重试';
      if (s === 429) return '操作太频繁，请稍后重试';
      if (s >= 500) return '知乎服务暂时不可用，请稍后重试';
    }
  }

  if (isRecord(error)) {
    const record = error as Record<string, object>;
    const code = record['code'];
    if (String(code) === 'ECONNABORTED' || String(code) === 'ETIMEDOUT') {
      return '请求超时，请检查网络后重试';
    }
    if (String(code) === 'ERR_NETWORK') return '网络连接失败，请检查网络后重试';

    const message = record['message'];
    if (typeof message === 'string' && (message as string).length > 0) {
      return message as string;
    }
  }

  if (error instanceof Error && error.message.length > 0) {
    return error.message;
  }

  return '未知错误';
}
