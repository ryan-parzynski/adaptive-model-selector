#!/usr/bin/env python3
"""
Test harness v2: validate reference switcher against 10 real task fixtures.
Fixed version with stall detection, alert failure handling.
"""

import sys
from reference_switcher_v2 import DecisionCore, ActionType
from test_fixtures import ALL_FIXTURES


def test_all_fixtures():
    """Run all fixtures through the decision core."""

    # Setup with soft/hard timeout thresholds
    routing_table = {
        "chat": ["primary", "fallback_1", "escalate"],
        "vision": ["vision_fast", "vision_slow", "escalate"],
        "search": ["search_primary", "search_fallback"],
        "short_generation": ["local_gpu", "fallback"],
        "trivial_generation": ["local_gpu", "local_cpu"],
        "generation": ["local_gpu", "fallback"],
        "cron_alert": ["ntfy_server", "ntfy_fallback"],
    }

    decision_core = DecisionCore(
        routing_table,
        timeout_threshold_ms=5000,    # Soft timeout: stall detection
        hard_timeout_ms=30000,         # Hard timeout: escalate
    )

    passed = 0
    failed = 0

    print("\n" + "=" * 80)
    print("REFERENCE SWITCHER VALIDATION TEST (v2 - Fixed)")
    print("=" * 80)

    for fixture in ALL_FIXTURES:
        print(f"\n[{fixture.box.upper()}] {fixture.name}")
        print(f"  Input: {fixture.input_tokens} tokens, {fixture.job_type}")
        print(f"  Elapsed: {fixture.elapsed_ms}ms (soft: 5000ms, hard: 30000ms)")
        print(f"  Expected: {fixture.expected_outcome} @ depth={fixture.expected_fallback_depth}")

        # Call decision core
        decision = decision_core.decide(
            job_id=fixture.job_id,
            job_type=fixture.job_type,
            current_model=fixture.initial_model,
            elapsed_ms=fixture.elapsed_ms,
            residency_history={},  # For now, no residency data
        )

        print(f"  Decision: {decision.action.value} {decision.model_id} @ {decision.lane}")
        print(f"    Reason: {decision.reason}")
        print(f"    Timeout context: {decision.timeout_context}")

        # Validate
        errors = []

        # Check timeout detection
        if fixture.timeout_expected:
            if not decision.timeout_context:
                errors.append(f"Expected timeout_context=True, got {decision.timeout_context}")

        # Check action
        expected_action_map = {
            "success": ActionType.LOAD,
            "fallback": ActionType.FALLBACK,
            "escalate": ActionType.ESCALATE,
            "stall": ActionType.LOAD,  # Stall is a load that takes a long time (retry same)
            "timeout": ActionType.FALLBACK,
        }

        expected_action = expected_action_map.get(fixture.expected_outcome)
        if expected_action and decision.action != expected_action:
            errors.append(f"Expected action={expected_action.value}, got {decision.action.value}")

        # Check fallback depth (for stall, depth should be 0; for fallback, > 0)
        if fixture.expected_outcome == "stall":
            # Stall should retry same model (depth=0)
            if decision.fallback_depth != 0:
                errors.append(f"Stall should have depth=0 (retry same), got {decision.fallback_depth}")
        elif fixture.expected_fallback_depth > 0:
            # Non-stall fallback should have correct depth
            if decision.fallback_depth != fixture.expected_fallback_depth:
                errors.append(f"Expected fallback_depth={fixture.expected_fallback_depth}, got {decision.fallback_depth}")

        if errors:
            print(f"  ❌ FAILED:")
            for error in errors:
                print(f"    - {error}")
            failed += 1
        else:
            print(f"  ✅ PASSED")
            passed += 1

    # Summary
    print("\n" + "=" * 80)
    print(f"RESULTS: {passed}/{len(ALL_FIXTURES)} passed, {failed}/{len(ALL_FIXTURES)} failed")
    print("=" * 80)

    return failed == 0


if __name__ == "__main__":
    success = test_all_fixtures()
    sys.exit(0 if success else 1)
