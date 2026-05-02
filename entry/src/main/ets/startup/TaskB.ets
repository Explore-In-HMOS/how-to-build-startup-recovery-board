import { StartupTask, common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

/**
 * TaskB — Data Loading.
 *
 * Depends on TaskA. The startup framework guarantees TaskA.init()
 * has completed before TaskB.init() begins.
 * TaskC depends on this task.
 *
 * Demonstrates: dependency chaining (A → B → C)
 */
@Sendable
export default class TaskB extends StartupTask {
  constructor() {
    super();
  }

  /**
   * Simulates data loading with a 1200 ms delay.
   * Only runs after TaskA has finished (dependency guarantee).
   *
   * @param context - The AbilityStage context provided by the framework
   * @returns A result string retrievable via StartupManager.getStartupTaskResult()
   */
  async init(context: common.AbilityStageContext): Promise<string> {
    const startTime = Date.now();
    hilog.info(0x0000, 'TaskB', '>>> TaskB [Data Load] started at %{public}d (after TaskA)', startTime);

    // Simulate data loading work
    await new Promise<void>((resolve) => {
      setTimeout(() => resolve(), 1200);
    });

    const endTime = Date.now();
    const duration = endTime - startTime;
    hilog.info(0x0000, 'TaskB', '<<< TaskB [Data Load] completed in %{public}d ms', duration);

    AppStorage.setOrCreate<number>('taskB_start', startTime);
    AppStorage.setOrCreate<number>('taskB_end', endTime);

    return `Data loaded in ${duration}ms`;
  }

  /**
   * TaskB depends on TaskA — the framework resolves this before calling init().
   */
  get dependencies(): string[] {
    return ['TaskA'];
  }
}
