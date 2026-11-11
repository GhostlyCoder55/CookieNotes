const { createRequire } = require('module');
const path = require('path');
const { getDefaultConfig } = require('expo/metro-config');

// Resolve @svgr/* and path-dirname relative to react-native-svg-transformer so it
// works identically whether npm hoists dependencies or nests them on EAS builders.
const svgTransformerRequire = createRequire(
  require.resolve('react-native-svg-transformer/package.json')
);
const { resolveConfig, transform: svgrTransform } = svgTransformerRequire('@svgr/core');
const pluginSvgo = svgTransformerRequire('@svgr/plugin-svgo');
const pluginJsx = svgTransformerRequire('@svgr/plugin-jsx');
const resolveConfigDir = svgTransformerRequire('path-dirname');

const defaultConfig = getDefaultConfig(__dirname);
const upstreamTransformer = require(defaultConfig.transformer.babelTransformerPath);

const defaultSVGRConfig = {
  native: true,
  plugins: [pluginSvgo, pluginJsx],
  svgoConfig: {
    plugins: [
      {
        name: 'preset-default',
        params: {
          overrides: {
            inlineStyles: {
              onlyMatchedOnce: false,
            },
            removeViewBox: false,
            removeUnknownsAndDefaults: false,
            convertColors: false,
          },
        },
      },
    ],
  },
};

module.exports = {
  ...upstreamTransformer,
  async transform({ src, filename, ...rest }) {
    if (path.extname(filename).toLowerCase() === '.svg') {
      const userConfig = await resolveConfig(resolveConfigDir(filename));
      const svgrConfig = userConfig
        ? { ...defaultSVGRConfig, ...userConfig }
        : defaultSVGRConfig;
      const transformedCode = await svgrTransform(src, svgrConfig, {
        filePath: filename,
      });
      return upstreamTransformer.transform({
        src: transformedCode,
        filename,
        ...rest,
      });
    }
    return upstreamTransformer.transform({ src, filename, ...rest });
  },
};
