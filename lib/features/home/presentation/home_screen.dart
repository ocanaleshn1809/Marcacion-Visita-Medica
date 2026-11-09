import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/domain/session_identity.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../visits/data/location_service.dart';
import '../../visits/data/tracking_api.dart';
import '../../visits/data/tracking_store.dart';
import '../../visits/data/visit_api.dart';
import '../../visits/domain/medical_visit.dart';
import '../../visits/domain/tracking_models.dart';
import '../../visits/presentation/visit_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});

  final AuthController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final SessionIdentity _identity;
  late final VisitController _visitController;

  @override
  void initState() {
    super.initState();
    final session = widget.controller.session!;
    _identity = SessionIdentity.fromToken(session.accessToken);
    _visitController = VisitController(
      gateway: VisitApi(),
      trackingGateway: TrackingApi(),
      trackingStore: const SecureTrackingStore(),
      locationGateway: DeviceLocationService(),
      accessToken: session.accessToken,
      userId: _identity.userId ?? -1,
    )..loadToday();
  }

  @override
  void dispose() {
    _visitController.dispose();
    super.dispose();
  }

  Future<void> _startVisit(MedicalVisit visit) async {
    final started = await _visitController.startVisit(visit);
    if (!mounted) return;
    if (started) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Visita iniciada y ubicación registrada.'),
        ),
      );
    }
  }

  Future<void> _finishVisit() async {
    final summary = await _visitController.finishVisit();
    if (!mounted || summary == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => _VisitSummaryDialog(
        summary: summary,
        visitorName: _identity.displayName,
      ),
    );
  }

  Future<void> _rescheduleVisit() async {
    final active = _visitController.activeVisit;
    if (active == null) return;
    final request = await showDialog<RescheduleRequest>(
      context: context,
      builder: (context) => _RescheduleDialog(visit: active.visit),
    );
    if (request == null || !mounted) return;
    final success = await _visitController.rescheduleActiveVisit(request);
    if (!mounted || !success) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Visita reagendada para ${_dateTime(context, request.plannedStart)}.',
        ),
      ),
    );
    await _visitController.loadToday();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MERCURIUS',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: widget.controller.signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A1812), AppColors.black],
          ),
        ),
        child: SafeArea(
          top: false,
          child: ListenableBuilder(
            listenable: _visitController,
            builder: (context, _) => RefreshIndicator(
              onRefresh: _visitController.loadToday,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
                    sliver: SliverToBoxAdapter(
                      child: _VisitorSelector(identity: _identity),
                    ),
                  ),
                  if (_visitController.errorMessage != null)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                      sliver: SliverToBoxAdapter(
                        child: _ErrorBanner(
                          message: _visitController.errorMessage!,
                          onRetry: _visitController.activeVisit == null
                              ? _visitController.loadToday
                              : null,
                        ),
                      ),
                    ),
                  if (_visitController.activeVisit case final active?)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      sliver: SliverToBoxAdapter(
                        child: _ActiveVisitCard(
                          active: active,
                          isBusy: _visitController.isCapturingLocation,
                          onFinish: _finishVisit,
                          onReschedule: _rescheduleVisit,
                        ),
                      ),
                    )
                  else ...[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                      sliver: SliverToBoxAdapter(
                        child: _SectionHeader(
                          count: _visitController.visits.length,
                        ),
                      ),
                    ),
                    if (_visitController.isLoading)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_visitController.visits.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyVisits(),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                        sliver: SliverList.separated(
                          itemCount: _visitController.visits.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final visit = _visitController.visits[index];
                            return _VisitCard(
                              visit: visit,
                              isBusy: _visitController.isCapturingLocation,
                              onStart: () => _startVisit(visit),
                            );
                          },
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VisitorSelector extends StatelessWidget {
  const _VisitorSelector({required this.identity});

  final SessionIdentity identity;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: identity.displayName,
      decoration: const InputDecoration(
        labelText: 'Visitador',
        prefixIcon: Icon(Icons.person_outline_rounded),
      ),
      items: [
        DropdownMenuItem(
          value: identity.displayName,
          child: Text(identity.displayName, overflow: TextOverflow.ellipsis),
        ),
      ],
      onChanged: (_) {},
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Visitas de hoy',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.forest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('$count programadas'),
        ),
      ],
    );
  }
}

class _VisitCard extends StatelessWidget {
  const _VisitCard({
    required this.visit,
    required this.isBusy,
    required this.onStart,
  });

  final MedicalVisit visit;
  final bool isBusy;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.graphite.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF22342B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(
                backgroundColor: AppColors.forest,
                foregroundColor: AppColors.mint,
                child: Icon(Icons.medical_services_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visit.doctorName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _plannedRange(context, visit),
                      style: const TextStyle(color: AppColors.mint),
                    ),
                  ],
                ),
              ),
              _StatusChip(status: visit.status),
            ],
          ),
          if (visit.clinicName case final clinic?) ...[
            const SizedBox(height: 14),
            _DetailLine(icon: Icons.local_hospital_outlined, text: clinic),
          ],
          if (visit.specialtyName case final specialty?) ...[
            const SizedBox(height: 8),
            _DetailLine(icon: Icons.badge_outlined, text: specialty),
          ],
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: visit.canStart && !isBusy ? onStart : null,
            icon: isBusy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow_rounded),
            label: Text(
              visit.canStart ? 'Iniciar visita' : 'Visita no disponible',
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveVisitCard extends StatelessWidget {
  const _ActiveVisitCard({
    required this.active,
    required this.isBusy,
    required this.onFinish,
    required this.onReschedule,
  });

  final ActiveVisit active;
  final bool isBusy;
  final VoidCallback onFinish;
  final VoidCallback onReschedule;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF164B35), Color(0xFF0B2118)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.emerald.withValues(alpha: .65)),
        boxShadow: [
          BoxShadow(
            color: AppColors.emerald.withValues(alpha: .12),
            blurRadius: 28,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              _PulseDot(),
              SizedBox(width: 10),
              Text(
                'VISITA EN CURSO',
                style: TextStyle(
                  color: AppColors.mint,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            active.visit.doctorName,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          if (active.visit.clinicName case final clinic?) ...[
            const SizedBox(height: 6),
            Text(
              clinic,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 22),
          _DetailLine(
            icon: Icons.schedule_rounded,
            text: 'Inicio: ${_time(context, active.startedAt)}',
          ),
          const SizedBox(height: 10),
          _DetailLine(
            icon: Icons.location_on_outlined,
            text: _coordinates(active.startLocation),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: isBusy ? null : onReschedule,
            icon: const Icon(Icons.event_repeat_rounded),
            label: const Text('Reagendar visita'),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.textPrimary,
              foregroundColor: AppColors.black,
            ),
            onPressed: isBusy ? null : onFinish,
            icon: isBusy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.stop_rounded),
            label: const Text('Finalizar visita médica'),
          ),
        ],
      ),
    );
  }
}

class _VisitSummaryDialog extends StatelessWidget {
  const _VisitSummaryDialog({required this.summary, required this.visitorName});

  final VisitSummary summary;
  final String visitorName;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const CircleAvatar(
        backgroundColor: AppColors.forest,
        foregroundColor: AppColors.mint,
        child: Icon(Icons.check_rounded),
      ),
      title: const Text('Visita finalizada', textAlign: TextAlign.center),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _SummaryRow(label: 'Visitador', value: visitorName),
            _SummaryRow(label: 'Médico', value: summary.visit.doctorName),
            _SummaryRow(
              label: 'Inicio',
              value: _dateTime(context, summary.startedAt),
            ),
            _SummaryRow(
              label: 'Final',
              value: _dateTime(context, summary.finishedAt),
            ),
            _SummaryRow(
              label: 'GPS inicial',
              value: _coordinates(summary.startLocation),
            ),
            _SummaryRow(
              label: 'GPS final',
              value: _coordinates(summary.endLocation),
            ),
            const SizedBox(height: 8),
            const Text(
              'El horario y las ubicaciones del tracking fueron guardados en el servidor.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Entendido'),
        ),
      ],
    );
  }
}

class _RescheduleDialog extends StatefulWidget {
  const _RescheduleDialog({required this.visit});

  final MedicalVisit visit;

  @override
  State<_RescheduleDialog> createState() => _RescheduleDialogState();
}

class _RescheduleDialogState extends State<_RescheduleDialog> {
  final _reasonController = TextEditingController();
  late DateTime _date;
  late TimeOfDay _time;
  int _durationMinutes = 30;
  String? _error;

  @override
  void initState() {
    super.initState();
    final base = (widget.visit.plannedStart ?? DateTime.now()).toLocal();
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    _date = DateTime(tomorrow.year, tomorrow.month, tomorrow.day);
    _time = TimeOfDay(hour: base.hour, minute: base.minute);
    final plannedDuration = widget.visit.plannedEnd?.difference(base).inMinutes;
    if (plannedDuration != null && [15, 30, 45, 60].contains(plannedDuration)) {
      _durationMinutes = plannedDuration;
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  DateTime get _plannedStart =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected != null) setState(() => _date = selected);
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(context: context, initialTime: _time);
    if (selected != null) setState(() => _time = selected);
  }

  void _submit() {
    final reason = _reasonController.text.trim();
    final start = _plannedStart;
    if (reason.isEmpty) {
      setState(() => _error = 'Escribe el motivo del reagendamiento.');
      return;
    }
    if (!start.isAfter(DateTime.now())) {
      setState(() => _error = 'La nueva fecha debe estar en el futuro.');
      return;
    }
    Navigator.pop(
      context,
      RescheduleRequest(
        reason: reason,
        plannedStart: start,
        plannedEnd: start.add(Duration(minutes: _durationMinutes)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reagendar visita'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Motivo',
                hintText: 'Ej. El médico solicitó otro horario',
              ),
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today_outlined),
              title: const Text('Fecha'),
              subtitle: Text(
                '${_date.day.toString().padLeft(2, '0')}/'
                '${_date.month.toString().padLeft(2, '0')}/${_date.year}',
              ),
              onTap: _pickDate,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_outlined),
              title: const Text('Hora de inicio'),
              subtitle: Text(_time.format(context)),
              onTap: _pickTime,
            ),
            DropdownButtonFormField<int>(
              initialValue: _durationMinutes,
              decoration: const InputDecoration(labelText: 'Duración'),
              items: const [15, 30, 45, 60]
                  .map(
                    (minutes) => DropdownMenuItem(
                      value: minutes,
                      child: Text('$minutes minutos'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) setState(() => _durationMinutes = value);
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Reagendar')),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 3),
          SelectableText(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.forest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(status, style: const TextStyle(fontSize: 11)),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 9),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.danger.withValues(alpha: .35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
          if (onRetry != null)
            IconButton(
              tooltip: 'Reintentar',
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
    );
  }
}

class _EmptyVisits extends StatelessWidget {
  const _EmptyVisits();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_available_outlined,
              size: 58,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 16),
            Text('No tienes visitas programadas para hoy.'),
            SizedBox(height: 7),
            Text(
              'Desliza hacia abajo para actualizar.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulseDot extends StatelessWidget {
  const _PulseDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(
        color: AppColors.mint,
        shape: BoxShape.circle,
      ),
    );
  }
}

String _plannedRange(BuildContext context, MedicalVisit visit) {
  final start = visit.plannedStart;
  final end = visit.plannedEnd;
  if (start == null) return 'Horario pendiente';
  if (end == null) return _time(context, start);
  return '${_time(context, start)} – ${_time(context, end)}';
}

String _time(BuildContext context, DateTime value) {
  return MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay.fromDateTime(value.toLocal()),
    alwaysUse24HourFormat: true,
  );
}

String _dateTime(BuildContext context, DateTime value) {
  final local = value.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/${local.year} '
      '${_time(context, local)}';
}

String _coordinates(GeoPoint point) {
  return '${point.latitude.toStringAsFixed(6)}, '
      '${point.longitude.toStringAsFixed(6)} '
      '(±${point.accuracy.toStringAsFixed(0)} m)';
}
