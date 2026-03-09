// lib/screens/workflows_screen.dart
// Workflow'ları listele ve çalıştır

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/workflow.dart';
import '../services/workflow_service.dart';

class WorkflowsScreen extends StatefulWidget {
  const WorkflowsScreen({super.key});

  @override
  State<WorkflowsScreen> createState() => _WorkflowsScreenState();
}

class _WorkflowsScreenState extends State<WorkflowsScreen> {
  late Future<List<Workflow>> _workflowsFuture;
  String? _runningWorkflowId;
  String? _workflowOutput;
  bool _showOutput = false;

  @override
  void initState() {
    super.initState();
    _loadWorkflows();
  }

  void _loadWorkflows() {
    setState(() {
      _workflowsFuture = WorkflowService().loadWorkflows();
    });
  }

  Future<void> _runWorkflow(Workflow workflow) async {
    setState(() {
      _runningWorkflowId = workflow.id;
      _workflowOutput = 'Workflow başlatılıyor...\n\n';
      _showOutput = true;
    });

    try {
      final result = await WorkflowService().runWorkflow(workflow);

      if (mounted) {
        final results = result['results'] as Map<String, dynamic>;
        String output = '';

        for (final entry in results.entries) {
          final scriptName = entry.key;
          final scriptResult = entry.value as Map<String, dynamic>;
          final ok = scriptResult['ok'] == true;

          output += '${ok ? "✅" : "❌"} $scriptName\n';
          if (!ok && scriptResult['error'] != null) {
            output += '   Error: ${scriptResult['error']}\n';
          }
          output += '\n';
        }

        output += result['ok'] == true
            ? '\n✅ Workflow başarıyla tamamlandı'
            : '\n❌ Workflow hata ile sonlandı';

        // Workflow'u güncelle
        final updatedWorkflow = workflow.copyWith(
          lastRun: DateTime.now(),
          lastStatus: result['ok'] == true ? 'success' : 'failed',
        );
        await WorkflowService().updateWorkflow(updatedWorkflow);

        setState(() {
          _workflowOutput = output;
          _runningWorkflowId = null;
        });

        _loadWorkflows();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _workflowOutput = '❌ Error: $e';
          _runningWorkflowId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1D2E),
        title: const Text(
          'Workflows',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () async {
              // Workflow'ları sıfırla ve varsayılanlara dön
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('workflows');
              _loadWorkflows();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Workflow\'lar varsayılana sıfırlandı'),
                    backgroundColor: Color(0xFF00C896),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<List<Workflow>>(
              future: _workflowsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Workflow\'lar yükleniyor...',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  );
                }

                final workflows = snapshot.data ?? [];
                if (workflows.isEmpty) {
                  return const Center(
                    child: Text(
                      'Workflow bulunamadı',
                      style: TextStyle(color: Colors.white54),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _loadWorkflows(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: workflows.length,
                    itemBuilder: (context, index) {
                      final workflow = workflows[index];
                      final isRunning = _runningWorkflowId == workflow.id;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _buildWorkflowCard(workflow, isRunning),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          if (_showOutput) _buildOutputPanel(),
        ],
      ),
    );
  }

  Widget _buildWorkflowCard(Workflow workflow, bool isRunning) {
    final statusColor = workflow.lastStatus == 'success'
        ? const Color(0xFF00C896)
        : workflow.lastStatus == 'failed'
        ? const Color(0xFFFF6B6B)
        : Colors.white24;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRunning
              ? const Color(0xFF6C63FF).withValues(alpha: 0.5)
              : Colors.white12,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workflow.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        workflow.description,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isRunning)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Color(0xFF6C63FF)),
                    ),
                  )
                else
                  IconButton(
                    onPressed: () => _runWorkflow(workflow),
                    icon: const Icon(Icons.play_circle_outline),
                    color: const Color(0xFF6C63FF),
                    iconSize: 32,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: workflow.scripts
                  .map(
                    (s) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        s,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            if (workflow.lastRun != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Son çalışma: ${_formatDate(workflow.lastRun!)}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ],
            if (workflow.schedule != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.white38,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Önerilen saat: ${workflow.schedule}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOutputPanel() {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2E),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Workflow Output',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white38,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _showOutput = false),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                _workflowOutput ?? 'Running...',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 13,
                  fontFamily: 'Courier',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Az önce';
    if (diff.inHours < 1) return '${diff.inMinutes} dakika önce';
    if (diff.inDays < 1) return '${diff.inHours} saat önce';
    if (diff.inDays < 7) return '${diff.inDays} gün önce';

    return '${date.day}/${date.month}/${date.year}';
  }
}
