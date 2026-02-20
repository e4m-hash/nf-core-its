process QIIME2_VSEARCH_UCHIME_DENOVO {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/envs/qiime2-amplicon-2024.10-py310-linux-conda.yml"
    container "qiime2/amplicon:2024.10"

    input:
    tuple val(meta), path(derep_table), path(derep_seqs)

    output:
    tuple val(meta), path(derep_table), path(derep_seqs), path("chimeras.qza"), emit: uchime
    path "versions.yml", emit: versions

    script:
    """
    qiime vsearch uchime-denovo \
        --i-sequences ${derep_seqs} \
        --i-table ${derep_table} \
        --o-chimeras chimeras.qza \
        --o-nonchimeras non_chimeras.qza \
        --o-stats chimera_stats.qza

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        qiime2: \$(qiime --version | sed 's/q2cli version //g' | sed 's/ .*//g')
    END_VERSIONS
    """
}
