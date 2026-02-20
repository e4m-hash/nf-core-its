process QIIME2_DEREPLICATE {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/envs/qiime2-amplicon-2024.10-py310-linux-conda.yml"
    container "qiime2/amplicon:2024.10"

    input:
    tuple val(meta), path(qza)

    output:
    tuple val(meta), path("derep_table.qza"), path("derep_seqs.qza"), emit: derep
    path "versions.yml", emit: versions

    script:
    def args   = task.ext.args   ?: ''

    """
    qiime vsearch dereplicate-sequences \
        --i-sequences $qza \
        --o-dereplicated-table derep_table.qza \
        --o-dereplicated-sequences derep_seqs.qza \
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        qiime2: \$(qiime --version | sed 's/q2cli version //g' | sed 's/ .*//g')
    END_VERSIONS
    """
}
