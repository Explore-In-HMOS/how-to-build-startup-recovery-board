import { StartupTask, common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

/**
 * TaskC — Analytics Processing.
 *
 * Depends on TaskB (which depends on TaskA).
 * This is the final task in the dependency chain: A → B → C.
 *
 * Demonstrates: deep dependency chains resolved by the framework
 */
@Sendable
export default class TaskC extends StartupTask {
  constructor() {
    super();
  }

  /**
   * Simulates analytics processing with an 800 ms delay.
   * Only runs after TaskB has finished.
   *
   * @param context - The AbilityStage context provided by the framework
   * @returns A result string retrievable via StartupManager.getStartupTaskResult()
   */
  async init(context: common.AbilityStageContext): Promise<string> {
    const startTime = Date.now();
    hilog.info(0x0000, 'TaskC', '>>> TaskC [Analytics] started at %{public}d (after TaskB)', startTime);

    // Simulate analytics processing
    await new Promise<void>((resolve) => {
      setTimeout(() => resolve(), 800);
    });

    const endTime = Date.now();
    const duration = endTime - startTime;
    hilog.info(0x0000, 'TaskC', '<<< TaskC [Analytics] completed in %{public}d ms', duration);

    AppStorage.setOrCreate<number>('taskC_start', startTime);
    AppStorage.setOrCreate<number>('taskC_end', endTime);

    return `Analytics processed in ${duration}ms`;
  }

  /**
   * TaskC depends on TaskB — end of the A → B → C chain.
   */
  get dependencies(): string[] {
    return ['TaskB'];
  }
}
