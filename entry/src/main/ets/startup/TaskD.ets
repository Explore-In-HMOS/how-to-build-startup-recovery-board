import { StartupTask, common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

/**
 * TaskD — Network Connectivity Check.
 *
 * Has NO dependencies, so it runs in parallel with TaskA
 * from the very start. This demonstrates that the startup
 * framework can execute independent tasks concurrently.
 *
 * Demonstrates: independent parallel execution alongside the A → B → C chain
 */
@Sendable
export default class TaskD extends StartupTask {
  constructor() {
    super();
  }

  /**
   * Simulates a network connectivity check with a 2000 ms delay.
   * Runs independently — does not wait for any other task.
   *
   * @param context - The AbilityStage context provided by the framework
   * @returns A result string retrievable via StartupManager.getStartupTaskResult()
   */
  async init(context: common.AbilityStageContext): Promise<string> {
    const startTime = Date.now();
    hilog.info(0x0000, 'TaskD', '>>> TaskD [Network] started at %{public}d (independent)', startTime);

    // Simulate network connectivity check
    await new Promise<void>((resolve) => {
      setTimeout(() => resolve(), 2000);
    });

    const endTime = Date.now();
    const duration = endTime - startTime;
    hilog.info(0x0000, 'TaskD', '<<< TaskD [Network] completed in %{public}d ms', duration);

    AppStorage.setOrCreate<number>('taskD_start', startTime);
    AppStorage.setOrCreate<number>('taskD_end', endTime);

    return `Network checked in ${duration}ms`;
  }

  /**
   * Empty array = no dependencies; runs immediately in parallel with TaskA.
   */
  get dependencies(): string[] {
    return [];
  }
}
