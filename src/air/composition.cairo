use cairo_verifier::air::global_values::{EcPoint, InteractionElements, GlobalValues};
use cairo_verifier::air::constants::{
    PUBLIC_MEMORY_STEP, DILUTED_N_BITS, DILUTED_SPACING, PEDERSEN_BUILTIN_RATIO,
    PEDERSEN_BUILTIN_REPETITIONS, segments
};
use cairo_verifier::air::public_input::{PublicInput, PublicInputTrait};
use cairo_verifier::air::diluted::get_diluted_product;
use cairo_verifier::air::pedersen::{eval_pedersen_x, eval_pedersen_y};
use cairo_verifier::air::autogenerated::{
    eval_composition_polynomial_inner, eval_oods_polynomial_inner
};
use cairo_verifier::common::math::{Felt252Div, Felt252PartialOrd, pow};
use cairo_verifier::common::asserts::assert_range_u128;

const SHIFT_POINT_X: felt252 = 0x49ee3eba8c1600700ee1b87eb599f16716b0b1022947733551fde4050ca6804;
const SHIFT_POINT_Y: felt252 = 0x3ca0cfe4b3bc6ddf346d49d06ea0ed34e621062c0e056c1d0405d266e10268a;

fn eval_composition_polynomial(
    interaction_elements: InteractionElements,
    public_input: @PublicInput,
    mask_values: Span<felt252>,
    constraint_coefficients: Span<felt252>,
    point: felt252,
    trace_domain_size: felt252,
    trace_generator: felt252
) -> felt252 {
    let memory_z = interaction_elements.memory_multi_column_perm_perm_interaction_elm;
    let memory_alpha = interaction_elements.memory_multi_column_perm_hash_interaction_elm0;

    // Public memory
    let public_memory_column_size = trace_domain_size / PUBLIC_MEMORY_STEP;
    assert_range_u128(public_memory_column_size);
    let public_memory_prod_ratio = public_input
        .get_public_memory_product_ratio(memory_z, memory_alpha, public_memory_column_size);

    // Diluted
    let diluted_z = interaction_elements.diluted_check_interaction_z;
    let diluted_alpha = interaction_elements.diluted_check_interaction_alpha;
    let diluted_prod = get_diluted_product(
        DILUTED_N_BITS, DILUTED_SPACING, diluted_z, diluted_alpha
    );

    // Periodic columns
    let n_steps = pow(2, *public_input.log_n_steps);
    let n_pedersen_hash_copies = n_steps / (PEDERSEN_BUILTIN_RATIO * PEDERSEN_BUILTIN_REPETITIONS);
    assert_range_u128(n_pedersen_hash_copies);
    let pedersen_point = pow(point, n_pedersen_hash_copies);
    let pedersen_points_x = eval_pedersen_x(pedersen_point);
    let pedersen_points_y = eval_pedersen_y(pedersen_point);

    let global_values = GlobalValues {
        trace_length: trace_domain_size,
        initial_pc: *public_input.segments.at(segments::PROGRAM).begin_addr,
        final_pc: *public_input.segments.at(segments::PROGRAM).stop_ptr,
        initial_ap: *public_input.segments.at(segments::EXECUTION).begin_addr,
        final_ap: *public_input.segments.at(segments::EXECUTION).stop_ptr,
        initial_pedersen_addr: *public_input.segments.at(segments::PEDERSEN).begin_addr,
        initial_rc_addr: *public_input.segments.at(segments::RANGE_CHECK).begin_addr,
        initial_bitwise_addr: *public_input.segments.at(segments::BITWISE).begin_addr,
        rc_min: *public_input.rc_min,
        rc_max: *public_input.rc_max,
        offset_size: 0x10000, // 2**16
        half_offset_size: 0x8000,
        pedersen_shift_point: EcPoint { x: SHIFT_POINT_X, y: SHIFT_POINT_Y },
        pedersen_points_x,
        pedersen_points_y,
        memory_multi_column_perm_perm_interaction_elm: memory_z,
        memory_multi_column_perm_hash_interaction_elm0: memory_alpha,
        rc16_perm_interaction_elm: interaction_elements.rc16_perm_interaction_elm,
        diluted_check_permutation_interaction_elm: interaction_elements
            .diluted_check_permutation_interaction_elm,
        diluted_check_interaction_z: diluted_z,
        diluted_check_interaction_alpha: diluted_alpha,
        memory_multi_column_perm_perm_public_memory_prod: public_memory_prod_ratio,
        rc16_perm_public_memory_prod: 1,
        diluted_check_first_elm: 0,
        diluted_check_permutation_public_memory_prod: 1,
        diluted_check_final_cum_val: diluted_prod
    };

    eval_composition_polynomial_inner(
        mask_values, constraint_coefficients, point, trace_generator, global_values
    )
}

fn eval_oods_polynomial(
    column_values: Span<felt252>,
    oods_values: Span<felt252>,
    constraint_coefficients: Span<felt252>,
    point: felt252,
    oods_point: felt252,
    trace_generator: felt252,
) -> felt252 {
    eval_oods_polynomial_inner(
        column_values, oods_values, constraint_coefficients, point, oods_point, trace_generator,
    )
}
