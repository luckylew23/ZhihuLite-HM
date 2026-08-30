module.exports = (api) => {
  api.cache(true);
  return {
    presets: [
      ['babel-preset-expo', { jsxImportSource: 'nativewind' }],
      'nativewind/babel',
    ],
    plugins: [
      // 解析 TS path alias '@/*' → 项目根（对应 tsconfig.json 的 paths）。
      // OHOS 构建（HMOS_BUILD=1）同样需要此映射，否则 Metro 无法解析 '@/...' 导入。
      [
        'module-resolver',
        {
          root: ['./'],
          alias: {
            '@': './',
          },
          extensions: ['.ts', '.tsx', '.js', '.jsx', '.json', '.native.ts', '.native.tsx'],
        },
      ],
    ],
  };
};
