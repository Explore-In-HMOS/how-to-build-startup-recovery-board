import { StartupConfigEntry, StartupConfig, StartupListener } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';

/**
 * MyStartupConfig — Startup framework configuration entry.
 *
 * The framework calls onConfig() once during app startup to obtain
 * the StartupConfig, which includes:
 *   - timeoutMs: maximum time allowed for all tasks to finish
 *   - startupListener: a StartupListener whose onCompleted() fires
 *     when every registered startup task has finished (or on error)
 *
 * Demonstrates: StartupConfigEntry.onConfig(), StartupListener.onCompleted()
 */
export default class MyStartupConfig extends StartupConfigEntry {

  /**
   * Called by the startup framework to retrieve configuration.
   * Registers a StartupListener and sets a 30-second timeout.
   *
   * @returns StartupConfig with timeout and listener
   */
  onConfig(): StartupConfig {
    hilog.info(0x0000, 'StartupConfig', '=== onConfig() called — configuring startup framework ===');
    hilog.info(0x0000, 'StartupConfig', 'Setting timeout to 30 000 ms');

    const listener: StartupListener = {
      /**
       * onCompleted — fires when ALL startup tasks have finished.
       * If any task failed or timed out, the error parameter is set.
       *
       * @param error - BusinessError if something went wrong, undefined on success
       */
      onCompleted(error: BusinessError | void): void {
        const completionTime = Date.now();

        if (error) {
          hilog.error(0x0000, 'StartupConfig',
            '!!! onCompleted — startup FAILED: %{public}s', JSON.stringify(error));
          AppStorage.setOrCreate<boolean>('startupError', true);
        } else {
          hilog.info(0x0000, 'StartupConfig',
            '*** onCompleted — all startup tasks finished successfully at %{public}d ***', completionTime);
        }

        AppStorage.setOrCreate<number>('allTasksCompletedTime', completionTime);
        AppStorage.setOrCreate<boolean>('allTasksCompleted', true);
      }
    };

    hilog.info(0x0000, 'StartupConfig', 'StartupListener registered — onCompleted will fire when all tasks finish');

    const config: StartupConfig = {
      timeoutMs: 30000,
      startupListener: listener
    };

    return config;
  }
}
