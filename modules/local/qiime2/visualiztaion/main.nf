process QIIME2_VISUALIZATION {
    tag "$meta.id"
    label 'process_medium'

    conda "${moduleDir}/envs/qiime2-amplicon-2024.10-py310-linux-conda.yml"
    container "qiime2/amplicon:2024.10"

    input:
    tuple val(meta), path(otu_table), path(otu_rep_seqs)

    output:
    tuple val(meta), path("otu-rep-seq.qzv"), emit: qzv
    path "versions.yml", emit: versions

    script:
    def args   = task.ext.args   ?: ''

    """
    qiime feature-table tabulate-seqs \
        --i-data ${otu_rep_seqs} \
        --o-visualization otu-rep-seq.qzv \
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        qiime2: \$(qiime --version | sed 's/q2cli version //g' | sed 's/ .*//g')
    END_VERSIONS
    """
}
