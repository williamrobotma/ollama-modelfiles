# Plan: gemma4 MTP variants

## Approach

Two file writes, one commit. Each Modelfile mirrors the `26b-a4b-it-qat-mtp` structure:
FROM + DRAFT + draft_num_predict, inheriting parent parameters.

## Steps

1. `modelfiles/gemma4/12b-it-qat-mtp/Modelfile` - 12B stock QAT + drafter
2. `modelfiles/gemma4/31b-it-qat-mtp/Modelfile` - 31B stock QAT + drafter
3. `rumdl check` + commit
