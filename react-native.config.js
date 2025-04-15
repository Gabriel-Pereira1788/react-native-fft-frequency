/**
 * @type {import('@react-native-community/cli-types').UserDependencyConfig}
 */
module.exports = {
  dependency: {
    platforms: {
      android: {
        sourceDir: './android',
        packageImportPath: 'import com.rnfftfrequency.RNFftFrequencyModule;',
        packageInstance: 'new RNFftFrequencyModule()',
      },
      ios: {
        sourceDir: './ios',
        podspecPath: './RNFftFrequencyModule.podspec',
      },
    },
  },
};
