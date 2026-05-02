import { startupManager } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DEG2RAD = Math.PI / 180;

/**
 * Describes one arc segment in the circular ring visualizer.
 * Each arc represents a single startup task.
 *
 * NOTE: Canvas API requires raw hex strings for strokeStyle —
 * $r() Resource objects are not supported. The matching color
 * resources are defined in color.json (task_a, task_a_dim, etc.)
 * and used wherever ArkUI components allow Resource colors.
 */
interface ArcInfo {
  name: string;
  label: Resource;
  color: string;       // matches $r('app.color.task_X')
  dimColor: string;    // matches $r('app.color.task_X_dim')
  startAngle: number;
  sweepAngle: number;
}

/**
 * Arc definitions — placed clockwise around the ring:
 *   Top    → TaskA (Config)    — blue
 *   Right  → TaskB (Data)      — green
 *   Bottom → TaskC (Analytics) — amber
 *   Left   → TaskD (Network)   — purple
 * Each arc spans 80° with 10° gaps.
 */
const ARCS: ArcInfo[] = [
  { name: 'TaskA', label: $r('app.string.task_a_label'), color: '#58A6FF', dimColor: '#3358A6FF', startAngle: -85, sweepAngle: 80 },
  { name: 'TaskB', label: $r('app.string.task_b_label'), color: '#3FB950', dimColor: '#333FB950', startAngle: 5,   sweepAngle: 80 },
  { name: 'TaskC', label: $r('app.string.task_c_label'), color: '#D29922', dimColor: '#33D29922', startAngle: 95,  sweepAngle: 80 },
  { name: 'TaskD', label: $r('app.string.task_d_label'), color: '#BC8CFF', dimColor: '#33BC8CFF', startAngle: 185, sweepAngle: 80 }
];

/**
 * Index — Root page hosting the Navigation container.
 *
 * Contains the circular Startup Task Visualizer as the root view
 * and routes to the Summary NavDestination via NavPathStack.
 */
@Entry
@Component
struct Index {
  /** NavPathStack replaces the deprecated router for page navigation */
  private navStack: NavPathStack = new NavPathStack();

  private taskADone: boolean = false;
  private taskBDone: boolean = false;
  private taskCDone: boolean = false;
  private taskDDone: boolean = false;
  private completedCount: number = 0;
  @State allDone: boolean = false;
  @State statusText: Resource | string = $r('app.string.status_initializing');
  @State activeTask: string = '';

  private renderSettings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.renderSettings);
  private canvasSize: number = 0;

  /**
   * Lifecycle hook: fires before the component renders.
   * Waits 600 ms for the canvas to be ready, then starts the replay.
   */
  aboutToAppear(): void {
    hilog.info(0x0000, 'IndexPage', 'aboutToAppear — scheduling startup replay');
    setTimeout(() => {
      this.beginReplay();
    }, 600);
  }

  /**
   * Reads timing data stored by each StartupTask in AppStorage and
   * schedules setTimeout callbacks that light up arcs at the correct
   * relative offsets, recreating the real startup timeline.
   *
   * If tasks haven't written their data yet, retries after 400 ms.
   */
  beginReplay(): void {
    const aStart = AppStorage.get<number>('taskA_start') as number;
    const aEnd = AppStorage.get<number>('taskA_end') as number;
    const bEnd = AppStorage.get<number>('taskB_end') as number;
    const cEnd = AppStorage.get<number>('taskC_end') as number;
    const dStart = AppStorage.get<number>('taskD_start') as number;
    const dEnd = AppStorage.get<number>('taskD_end') as number;

    if (!aStart || !dStart) {
      hilog.warn(0x0000, 'IndexPage', 'Task timing not yet available — retrying in 400 ms');
      this.statusText = $r('app.string.status_waiting');
      setTimeout(() => this.beginReplay(), 400);
      return;
    }

    // Use the earliest start as the baseline for relative offsets
    const baseTime = Math.min(aStart, dStart);
    hilog.info(0x0000, 'IndexPage', 'Replay starting — baseTime=%{public}d', baseTime);
    hilog.info(0x0000, 'IndexPage',
      'Offsets: A=%{public}d  B=%{public}d  C=%{public}d  D=%{public}d ms',
      aEnd - baseTime, bEnd - baseTime, cEnd - baseTime, dEnd - baseTime);

    const schedule: number[] = [
      aEnd - baseTime,
      bEnd - baseTime,
      cEnd - baseTime,
      dEnd - baseTime
    ];

    const labels: string[] = ['Config', 'Data', 'Analytics', 'Network'];

    for (let i = 0; i < schedule.length; i++) {
      const delay = schedule[i];
      const label = labels[i];
      this.scheduleTaskCompletion(delay, i, label);
    }
  }

  private scheduleTaskCompletion(delay: number, idx: number, label: string): void {
    setTimeout(() => {
      // Mark the corresponding task as done
      if (idx === 0) {
        this.taskADone = true;
      }
      if (idx === 1) {
        this.taskBDone = true;
      }
      if (idx === 2) {
        this.taskCDone = true;
      }
      if (idx === 3) {
        this.taskDDone = true;
      }

      this.activeTask = label;
      this.completedCount++;
      hilog.info(0x0000, 'IndexPage',
        'Arc lit: %{public}s (%{public}d/4)', label, this.completedCount);

      this.drawRing();

      if (this.completedCount >= 4) {
        this.allDone = true;
        this.statusText = $r('app.string.status_all_complete');
        this.activeTask = '';
        hilog.info(0x0000, 'IndexPage', 'All arcs lit — replay complete');
      } else {
        this.statusText = `${this.completedCount}/4 Done`;
      }
    }, Math.max(delay, 200));
  }

  /**
   * Returns the completion state for a task by its index.
   * Used by drawRing() to decide arc color.
   */
  isTaskDone(index: number): boolean {
    if (index === 0) {
      return this.taskADone;
    }
    if (index === 1) {
      return this.taskBDone;
    }
    if (index === 2) {
      return this.taskCDone;
    }
    return this.taskDDone;
  }

  /**
   * Draws the full ring visualization on the Canvas.
   * Each of the 4 arcs is drawn in its dim color, then overdrawn
   * in its bright color if the corresponding task has completed.
   * Also draws small dependency dots between A→B and B→C arcs.
   */
  drawRing(): void {
    if (this.canvasSize === 0) {
      return;
    }
    const w = this.ctx.width;
    const h = this.ctx.height;
    const s = this.canvasSize;
    const cx = w / 2;
    const cy = h / 2;
    const outerR = s / 2 - 8;
    const strokeW = 10;

    this.ctx.clearRect(0, 0, w, h);

    for (let i = 0; i < ARCS.length; i++) {
      const arc = ARCS[i];
      const done = this.isTaskDone(i);
      const startRad = arc.startAngle * DEG2RAD;
      const endRad = (arc.startAngle + arc.sweepAngle) * DEG2RAD;

      // Dim background arc (always visible)
      this.ctx.beginPath();
      this.ctx.arc(cx, cy, outerR, startRad, endRad);
      this.ctx.lineWidth = strokeW;
      this.ctx.lineCap = 'round';
      this.ctx.strokeStyle = arc.dimColor;
      this.ctx.stroke();

      // Bright foreground arc (only when task is done)
      if (done) {
        this.ctx.beginPath();
        this.ctx.arc(cx, cy, outerR, startRad, endRad);
        this.ctx.lineWidth = strokeW;
        this.ctx.lineCap = 'round';
        this.ctx.strokeStyle = arc.color;
        this.ctx.stroke();
      }
    }

    // Dependency indicator dots in the gaps between chained arcs (A→B, B→C)
    this.drawDot(cx, cy, outerR, -2.5);
    this.drawDot(cx, cy, outerR, 87.5);
  }

  /**
   * Draws a small circle at a given angle on the ring.
   * Used as a visual dependency indicator between adjacent arcs.
   */
  drawDot(cx: number, cy: number, r: number, angleDeg: number): void {
    const rad = angleDeg * DEG2RAD;
    this.ctx.beginPath();
    this.ctx.arc(cx + r * Math.cos(rad), cy + r * Math.sin(rad), 2.5, 0, Math.PI * 2);
    this.ctx.fillStyle = '#444444';
    this.ctx.fill();
  }

  /**
   * NavDestination builder: maps route names to destination components.
   * Called by the Navigation container when navStack.pushPathByName() is used.
   */
  @Builder
  PageRouter(name: string) {
    if (name === 'summary') {
      SummaryView()
    }
  }

  build() {
    Navigation(this.navStack) {
      Stack({ alignContent: Alignment.Center }) {

        // Canvas layer — ring arcs drawn behind the center content
        Canvas(this.ctx)
          .width('100%')
          .height('100%')
          .onReady(() => {
            this.canvasSize = Math.min(this.ctx.width, this.ctx.height);
            hilog.info(0x0000, 'IndexPage',
              'Canvas ready — w=%{public}d h=%{public}d ring=%{public}d',
              this.ctx.width, this.ctx.height, this.canvasSize);
            this.drawRing();
          })

        // Center content layer — status text and navigation
        Column() {
          Text($r('app.string.title_startup_tasks'))
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))

          Text(this.statusText)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .margin({ top: 2 })

          if (this.activeTask !== '') {
            Text(`✓ ${this.activeTask}`)
              .fontSize(12)
              .fontColor($r('app.color.success'))
              .margin({ top: 4 })
          }

          Text($r('app.string.label_dep_chain'))
            .fontSize(10)
            .fontColor($r('app.color.text_tertiary'))
            .margin({ top: 6 })

          if (this.allDone) {
            Text($r('app.string.label_view_results'))
              .fontSize(14)
              .fontColor($r('app.color.task_a'))
              .fontWeight(FontWeight.Medium)
              .margin({ top: 12 })
              .padding({ left: 14, right: 14, top: 6, bottom: 6 })
              .backgroundColor($r('app.color.btn_bg'))
              .borderRadius(20)
              .onClick(() => {
                hilog.info(0x0000, 'IndexPage', 'Navigating to Summary via NavPathStack');
                this.navStack.pushPathByName('summary', null);
              })
          }
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .height('100%')
      }
      .width('100%')
      .height('100%')
    }
    .navDestination(this.PageRouter)
    .hideTitleBar(true)
    .hideBackButton(true)
    .padding(30)
    .backgroundColor($r('app.color.bg_primary'))
    .width('100%')
    .height('100%')
  }
}


/**
 * SummaryView — NavDestination showing detailed startup results.
 *
 * Uses startupManager.getStartupTaskResult() to retrieve the
 * return value of each task's init() method.
 * Reads timing data from AppStorage to display duration bars.
 *
 * Demonstrates: StartupManager.getStartupTaskResult()
 */
@Component
struct SummaryView {
  @State tasks: TaskSummaryInfo[] = [];
  @State totalTime: number = 0;

  aboutToAppear(): void {
    hilog.info(0x0000, 'SummaryPage', 'aboutToAppear — loading startup task results');
    this.loadResults();
  }

  /**
   * Retrieves results from each startup task using
   * startupManager.getStartupTaskResult() and combines them
   * with timing data from AppStorage.
   */
  loadResults(): void {
    const meta: string[][] = [
      ['TaskA', 'Config Init',   '#58A6FF', 'None'],
      ['TaskB', 'Data Load',     '#3FB950', 'TaskA'],
      ['TaskC', 'Analytics',     '#D29922', 'TaskB'],
      ['TaskD', 'Network Check', '#BC8CFF', 'None']
    ];

    let earliest = Infinity;
    let latest = 0;
    const results: TaskSummaryInfo[] = [];

    for (const m of meta) {
      const taskName = m[0];
      let resultStr = '';

      // getStartupTaskResult() returns whatever init() resolved with
      try {
        resultStr = startupManager.getStartupTaskResult(taskName) as string;
        hilog.info(0x0000, 'SummaryPage',
          'getStartupTaskResult(%{public}s) = %{public}s', taskName, resultStr);
      } catch (e) {
        hilog.error(0x0000, 'SummaryPage',
          'getStartupTaskResult(%{public}s) failed: %{public}s', taskName, JSON.stringify(e));
        resultStr = 'N/A';
      }

      const start = AppStorage.get<number>(`${taskName}_start`) as number ?? 0;
      const end = AppStorage.get<number>(`${taskName}_end`) as number ?? 0;
      const duration = end - start;

      hilog.info(0x0000, 'SummaryPage',
        '%{public}s: start=%{public}d end=%{public}d duration=%{public}d ms',
        taskName, start, end, duration);

      if (start > 0 && start < earliest) {
        earliest = start;
      }
      if (end > latest) {
        latest = end;
      }

      results.push({
        name: taskName, label: m[1], color: m[2], deps: m[3],
        result: resultStr, duration: duration
      });
    }

    this.tasks = results;
    this.totalTime = latest > earliest ? latest - earliest : 0;
    hilog.info(0x0000, 'SummaryPage',
      'Total startup wall-clock time: %{public}d ms', this.totalTime);
  }

  /**
   * Builds a single task result row — compact for wearable:
   * color dot, label, duration bar, and time on one line.
   */
  @Builder
  TaskCard(task: TaskSummaryInfo) {
    Row() {
      // Color indicator dot
      Circle()
        .width(10)
        .height(10)
        .fill(task.color)
        .margin({ right: 8 })

      // Label + duration bar stacked vertically
      Column() {
        Row() {
          Text(task.label)
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(task.color)

          Blank()

          Text(`${task.duration}ms`)
            .fontSize(11)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')

        // Proportional duration bar
        Stack({ alignContent: Alignment.Start }) {
          Row()
            .width('100%')
            .height(4)
            .backgroundColor($r('app.color.bar_bg'))
            .borderRadius(2)

          Row()
            .width(`${Math.min((task.duration / Math.max(this.totalTime, 1)) * 100, 100)}%`)
            .height(4)
            .backgroundColor(task.color)
            .borderRadius(2)
        }
        .width('100%')
        .margin({ top: 6 })

        if (task.deps !== 'None') {
          Text(`→ ${task.deps}`)
            .fontSize(10)
            .fontColor($r('app.color.text_tertiary'))
            .margin({ top: 4 })
        }
      }
      .layoutWeight(1)
    }
    .backgroundColor($r('app.color.card_bg'))
    .borderRadius(14)
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  build() {
    NavDestination() {
      // Full-height scroll — header scrolls with content on small screen
      Scroll() {
        Column({ space: 10 }) {
          // Header
          Text($r('app.string.title_startup_results'))
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
            .margin({ top: 20 })

          Text(`Total: ${this.totalTime}ms`)
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .margin({ bottom: 4 })

          // Task cards
          ForEach(this.tasks, (task: TaskSummaryInfo) => {
            this.TaskCard(task)
          }, (task: TaskSummaryInfo) => task.name)
        }
        .padding({ left: 16, right: 16, bottom: 40 })
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .hideTitleBar(true)
    .backgroundColor($r('app.color.bg_primary'))
  }
}

/**
 * Data model for a single task's summary card.
 */
interface TaskSummaryInfo {
  name: string;
  label: string;
  color: string;
  deps: string;
  result: string;
  duration: number;
}
