process QIIME2_IMPORT {
    tag "import_manifest" 
    label 'process_single'

    conda "${moduleDir}/envs/qiime2-amplicon-2024.10-py310-linux-conda.yml"
    container "qiime2/amplicon:2024.10"

    input:
    tuple val(meta), path(manifest)

    output:
    // representative-sequences
    tuple val(meta), path("rps.qza"), emit: qza
    path "versions.yml", emit: versions

    script:
    def args   = task.ext.args   ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"

    """
    export MPLCONFIGDIR="./mplconfigdir"
    export NUMBA_CACHE_DIR="./numbacache"

    qiime tools import \
        --input-path "${manifest}" \
        --output-path rps.qza \
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        qiime2: \$( qiime --version | sed '1!d;s/.* //' )
    END_VERSIONS
    """
}