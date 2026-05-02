import { StartupTask, common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

/**
 * TaskA — Configuration Initialization.
 *
 * This is a root task with NO dependencies, so the startup
 * framework launches it immediately when the app starts.
 * TaskB depends on this task and will wait until it finishes.
 *
 * Demonstrates: StartupTask.init(), StartupTask.dependencies
 */
@Sendable
export default class TaskA extends StartupTask {
  constructor() {
    super();
  }

  /**
   * Called by the startup framework to execute this task.
   * Simulates configuration initialization with a 1500 ms delay.
   * Stores timing data in AppStorage for the UI visualizer.
   *
   * @param context - The AbilityStage context provided by the framework
   * @returns A result string retrievable via StartupManager.getStartupTaskResult()
   */
  async init(context: common.AbilityStageContext): Promise<string> {
    const startTime = Date.now();
    hilog.info(0x0000, 'TaskA', '>>> TaskA [Config Init] started at %{public}d', startTime);

    // Simulate configuration initialization work
    await new Promise<void>((resolve) => {
      setTimeout(() => resolve(), 1500);
    });

    const endTime = Date.now();
    const duration = endTime - startTime;
    hilog.info(0x0000, 'TaskA', '<<< TaskA [Config Init] completed in %{public}d ms', duration);

    // Persist timing so the UI can replay the startup sequence visually
    AppStorage.setOrCreate<number>('taskA_start', startTime);
    AppStorage.setOrCreate<number>('taskA_end', endTime);

    return `Config initialized in ${duration}ms`;
  }

  /**
   * Declares this task's dependencies.
   * Empty array = no dependencies; runs immediately at startup.
   */
  get dependencies(): string[] {
    return [];
  }
}
