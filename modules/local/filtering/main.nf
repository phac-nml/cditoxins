process FILTERING_BLAST {
    label 'process_single'

    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/pandas:2.2.1' :
        'biocontainers/pandas:2.2.1' }"

    input:
    path(txt)
    path(samplesheet)
    path(nohits)

    output:
    path("results.csv"), emit: results
    path "versions.yml"                      , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    filtering_blast.py ${samplesheet} ${nohits}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        filtering_blast : 0.1.0
    END_VERSIONS
    """

    stub:
    """
    touch results.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        filtering_blast : 0.1.0
    END_VERSIONS
    """
}