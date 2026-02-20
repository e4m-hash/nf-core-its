process QIIME2_FILTERING_FEATURE {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/envs/qiime2-amplicon-2024.10-py310-linux-conda.yml"
    container "qiime2/amplicon:2024.10"

    input:
    tuple val(meta), path(derep_table), path(derep_seqs), path(chimeras)

    output:
    tuple val(meta), path(derep_seqs), path(chimeras), path("table-nonchimeric.qza"), emit : nonchimeric
    path "versions.yml", emit: versions

    script:
    def args   = task.ext.args   ?: ''

    """
    qiime feature-table filter-features \
    --i-table ${derep_table} \
    --m-metadata-file ${chimeras} \
    --o-filtered-table table-nonchimeric.qza \
    ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        qiime2: \$(qiime --version | sed 's/q2cli version //g' | sed 's/ .*//g')
    END_VERSIONS
    """
}
