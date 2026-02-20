process QIIME2_FILTER_SEQUENCE {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/envs/qiime2-amplicon-2024.10-py310-linux-conda.yml"
    container "qiime2/amplicon:2024.10"

    input:
    tuple val(meta), path(derep_seqs),  path(chimeras), path(derep_nom_table)

    output:
    tuple val(meta), path(derep_nom_table), path("rep-seqs-nonchimeric.qza"), emit : rep_seq_nonchimeric
    path "versions.yml", emit: versions

    script:
    def args   = task.ext.args   ?: ''

    """
    qiime feature-table filter-seqs \
    --i-data ${derep_seqs} \
    --m-metadata-file ${chimeras} \
    --o-filtered-data rep-seqs-nonchimeric.qza \
    ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        qiime2: \$(qiime --version | sed 's/q2cli version //g' | sed 's/ .*//g')
    END_VERSIONS
    """
}
