/**
 * 调试日志：写入应用沙箱 filesDir/zhilite_debug.log，供 hdc 拉取分析。
 * 仅诊断用，release 亦可输出。
 */
import { fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';

export function writeDebugLog(ctx: common.UIAbilityContext, tag: string, msg: string): void {
  try {
    const p: string = ctx.filesDir + '/zhilite_debug.log';
    const f: fs.File = fs.openSync(p, fs.OpenMode.CREATE | fs.OpenMode.APPEND | fs.OpenMode.READ_WRITE);
    fs.writeSync(f.fd, tag + ' ' + msg + '\n');
    fs.closeSync(f);
  } catch (e) {
    console.error('debugLog fail ' + JSON.stringify(e));
  }
}
