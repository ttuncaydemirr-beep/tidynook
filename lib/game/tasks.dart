// Daily tasks (1.2): three small tasks per local day, made from the date with
// the same seeded() hash as the daily box, so everyone gets the same tasks on
// the same day as far as their progress allows (a task the player cannot do
// yet, such as a bonus box before bonus boxes unlock, is skipped and the next
// one in the day's order is taken). Every finished task gives one hint when it
// is claimed (or doubled with the optional `task_double` rewarded ad; tasks
// left unclaimed are claimed automatically the next day); three finished tasks
// on a day fill one step of the 7-step task chest. Progress
// keeps the state (see Progress.tasksFor and friends); this file is pure data
// and generation. Exported by content.dart.

import 'daily.dart';

/// Tasks per day.
const int tasksPerDay = 3;

/// Hints a finished task gives when claimed (the optional rewarded ad,
/// placement `task_double`, doubles it).
const int taskHintReward = 1;

/// Steps of the task chest: one per day on which all three tasks were done.
const int taskChestSteps = 7;

/// Hints a full chest gives when every 3rd style and every chest decor piece
/// is already owned.
const int chestBonusHints = 3;

/// The kinds of daily task. The index is stable (used for the text keys
/// `taskText<Name>`; see docs/V1_2_PLAN.md, "Contract A 1.2"); saves use [name].
enum TaskType {
  /// Finish [DailyTask.target] boxes of any kind (levels, replays, the daily
  /// box, bonus boxes, winter boxes).
  boxes,

  /// Finish a level that was not done before.
  newLevel,

  /// Finish today's daily box.
  daily,

  /// Finish a bonus box.
  bonus,

  /// Change the style of a piece of furniture.
  style,

  /// Use a hint.
  hint,

  /// Finish a mystery box (a mystery level or a mystery bonus box).
  mystery,

  /// Play a finished level again and finish it.
  replay,

  /// Finish a box with a little drawer.
  drawer,

  /// Finish a winter event box (only while the event runs).
  winter,
}

/// What the player can do on the day the tasks are made; a task type that is
/// not possible is skipped.
class TaskContext {
  /// A level that is not done yet exists.
  final bool hasNewLevel;

  /// Today's daily box is not finished yet.
  final bool dailyOpen;

  /// Bonus boxes are unlocked.
  final bool bonusUnlocked;

  /// At least one level is done (there is furniture and something to replay).
  final bool hasDone;

  /// A mystery level can be opened.
  final bool mysteryReachable;

  /// A level with a drawer can be opened.
  final bool drawerReachable;

  /// The winter event runs and its boxes can be played.
  final bool winterOpen;

  const TaskContext({
    this.hasNewLevel = true,
    this.dailyOpen = true,
    this.bonusUnlocked = false,
    this.hasDone = false,
    this.mysteryReachable = false,
    this.drawerReachable = false,
    this.winterOpen = false,
  });

  /// True when [type] can be done with this context.
  bool allows(TaskType type) {
    switch (type) {
      case TaskType.boxes:
      case TaskType.hint:
        return true;
      case TaskType.newLevel:
        return hasNewLevel;
      case TaskType.daily:
        return dailyOpen;
      case TaskType.bonus:
        return bonusUnlocked;
      case TaskType.style:
      case TaskType.replay:
        return hasDone;
      case TaskType.mystery:
        return mysteryReachable;
      case TaskType.drawer:
        return drawerReachable;
      case TaskType.winter:
        return winterOpen;
    }
  }
}

/// One task of a day.
class DailyTask {
  final TaskType type;

  /// How many times the action is needed (2 or 3 for [TaskType.boxes], else 1).
  final int target;

  /// How far the player got (0..[target]).
  int progress;

  /// The task's hint was given (claimed, doubled, or claimed automatically
  /// on the next day).
  bool claimed;

  /// The optional rewarded doubling of this task's hint was used.
  bool doubled;

  DailyTask({
    required this.type,
    this.target = 1,
    this.progress = 0,
    this.claimed = false,
    this.doubled = false,
  });

  bool get done => progress >= target;

  Map<String, dynamic> toJson() => <String, dynamic>{
        't': type.name,
        'n': target,
        'p': progress,
        'c': claimed,
        'x': doubled,
      };

  /// null for anything that is not a valid saved task.
  static DailyTask? fromJson(Object? json) {
    if (json is! Map) {
      return null;
    }
    final t = json['t'];
    TaskType? type;
    for (final v in TaskType.values) {
      if (v.name == t) {
        type = v;
      }
    }
    if (type == null) {
      return null;
    }
    final n = json['n'];
    final p = json['p'];
    final target = n is num && n >= 1 ? n.toInt() : 1;
    var progress = p is num && p > 0 ? p.toInt() : 0;
    if (progress > target) {
      progress = target;
    }
    final doubled = json['x'] == true && progress >= target;
    return DailyTask(
      type: type,
      target: target,
      progress: progress,
      claimed: (json['c'] == true && progress >= target) || doubled,
      doubled: doubled,
    );
  }
}

/// The day's order of task types: the same for everyone on [day] ("YYYY-MM-DD").
List<TaskType> taskOrderFor(String day) {
  final r = seeded('tidynook:tasks:$day');
  final order = List<TaskType>.of(TaskType.values);
  for (var i = order.length - 1; i > 0; i--) {
    final j = (r() * (i + 1)).floor();
    final t = order[i];
    order[i] = order[j];
    order[j] = t;
  }
  return order;
}

/// Box count of the "finish n boxes" task on [day]: 2 or 3.
int boxesTargetFor(String day) {
  final r = seeded('tidynook:tasks:boxes:$day');
  return r() < 0.5 ? 2 : 3;
}

/// The [tasksPerDay] tasks of [day] for a player in [ctx]: the first possible
/// types of [taskOrderFor]. Deterministic.
List<DailyTask> generateDailyTasks(String day, TaskContext ctx) {
  final out = <DailyTask>[];
  for (final t in taskOrderFor(day)) {
    if (out.length == tasksPerDay) {
      break;
    }
    if (!ctx.allows(t)) {
      continue;
    }
    out.add(DailyTask(
      type: t,
      target: t == TaskType.boxes ? boxesTargetFor(day) : 1,
    ));
  }
  return out;
}

/// What a full task chest gave.
enum ChestRewardKind {
  /// The 3rd style of the piece of level [ChestReward.value].
  style,

  /// Chest decor piece [ChestReward.value] (0..chestDecorCount-1).
  decor,

  /// [ChestReward.value] hints (everything else is owned already).
  hints,
}

class ChestReward {
  final ChestRewardKind kind;
  final int value;
  const ChestReward(this.kind, this.value);

  @override
  bool operator ==(Object other) =>
      other is ChestReward && other.kind == kind && other.value == value;

  @override
  int get hashCode => Object.hash(kind, value);

  @override
  String toString() => 'ChestReward(${kind.name}, $value)';
}
