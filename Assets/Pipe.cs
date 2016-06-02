using UnityEngine;
using System.Collections;
using System.Collections.Generic;

/*
 * Prepares data to be sent to the shader in order to render a pipe around a string of points (called the spine of the pipe).
 * The geometry shader generates a ring of vertices around each point.
 * Then it generates a triangle strip between each ring to complete the shell of the pipe.
 * End caps are special cases where a ring of zero radius is generated.
 */
[RequireComponent(typeof(MeshFilter))]
public class Pipe : MonoBehaviour {
  public int nNodes = 10;
  public float length = 10;
  public float radius = 1;

  public Vector3[] positions;
  public Vector3[] normals; // The plane normal of each ring to be generated.
  public Vector3[] tangents; // Do not confuse this as the tangent of the spine. It is called tangents because it uses the `tangent` channel to be passed into the shader. The first point of the ring is positions[i] + radii[i] * tangents[i]. A rotation operator is used to rotate tangent[i] about normal[i]. Then the next point of the ring is generated again by positions[i] + radii[i] * tangents[i].
  public float[] radii;
  public Color[] colors;
  private Mesh mesh;

  void Awake() {
    mesh = GetComponent<MeshFilter>().mesh;

    positions = new Vector3[nNodes];
    normals = new Vector3[nNodes];
    tangents = new Vector3[nNodes];
    radii = new float[nNodes];
    colors = new Color[nNodes];

    // create a string of points in a straight line with length `length`.
    float p;
    for (int i = 0; i < nNodes; i++) {
      p = 1f * i / (nNodes- 1);
      positions[i] = new Vector3(0, 0, length * p);
      tangents[i] = new Vector3(1, 0, 0); // initialiaze tangents to arbitrary
      radii[i] = radius;
      colors[i] = new Color(p, .5f, .1f, 1);
    }
    // close end caps
    radii[0] = 0;
    radii[radii.Length - 1] = 0;

    // indices for lines
    // indices are used so that unity know what are the pairs of vertices to send to the shader.
    // this is analogous to mesh.triangles, but because we want to use lines instead of triangles, we need to set indices using mesh.SetIndices.
    int[] indices = new int[2 * (nNodes - 1)];
    for (int i = 0; i < nNodes - 1; i++) {
      indices[2 * i] = i;
      indices[2 * i + 1] = i + 1;
    }

    mesh.Clear();
    mesh.vertices = positions;
    mesh.SetIndices(indices, MeshTopology.Lines, 0);
    mesh.RecalculateBounds();
  }

  void Start() {

  }

  void Update() {
    // Everything in update is for animating the pipe just for fun.

    // movements
    float percent;
    float a;
    for (int i = 0; i < positions.Length; i++) {
      percent = 1f * i / (positions.Length - 1);
      //positions[i] = new Vector3(9 * width * percent * Mathf.Sin(6 * percent * Time.time + 2f * Mathf.PI * percent), positions[i].y, length * percent);
    }

    // update ring normals
    normals[0] = (positions[0] - positions[1]).normalized;
    for (int i = 1; i < normals.Length - 1; i++) {
      Vector3 forward = positions[i - 1] - positions[i];
      Vector3 backward = positions[i + 1] - positions[i];
      normals[i] = FindBisectingPlane(forward, backward, tangents[i]);
    }
    normals[normals.Length - 1] = -(positions[positions.Length - 2] - positions[positions.Length - 1]).normalized;

    // update ring tangents
    for (int i = 0; i < tangents.Length; i++) {
      // could neighboring tangents drift out of alignment over time?
      tangents[i] = Vector3.ProjectOnPlane(tangents[i], normals[i]).normalized;
    }

    // place radius as fourth component of tangent
    Vector4[] meshTangents = new Vector4[tangents.Length];
    for (int i = 0; i < meshTangents.Length; i++) {
      percent = 1f * i / (positions.Length - 1);
      a = Mathf.Sin(percent * Time.time + Mathf.PI * percent);
      if (i != 0 && i != radii.Length - 1) {
        radii[i] = 3 * radius * a * a;
      }
      meshTangents[i] = new Vector4(tangents[i].x, tangents[i].y, tangents[i].z, radii[i]);
    }

    // set changes
    mesh.vertices = positions;
    mesh.normals = normals;
    mesh.tangents = meshTangents;
    mesh.colors = colors;
    mesh.RecalculateBounds();

    // draw normals and tangents
    for (int i = 0; i < positions.Length; i++) {
      Debug.DrawRay(transform.position + transform.rotation * positions[i], 
        transform.rotation * normals[i] * 0.1f, 
        new Color(1, 0, 0));
      Debug.DrawRay(transform.position + transform.rotation * positions[i], 
        transform.rotation * tangents[i] * 0.1f, 
        new Color(0, 1, 0));
    }

    transform.Rotate(Vector3.forward, 20 * Time.deltaTime);
  }

  private Vector3 FindBisector(Vector3 forward, Vector3 backward, Vector3 tangent) {
    // Find the vector that bisects forward and backward.

    Vector3 bisector = forward.normalized + backward.normalized;
    if (bisector.magnitude == 0) {
      // this case happens when forward and backward are parallel or anti-parallel.
      return Vector3.Cross(tangent, forward).normalized;
    } else {
      return bisector.normalized;
    }
  }

  private Vector3 FindBisectingPlane(Vector3 forward, Vector3 backward, Vector3 tangent) {
    // Used this to find the normal of the ring.

    Vector3 bisector = forward.normalized + backward.normalized;
    if (bisector.magnitude == 0 || bisector.magnitude == 2) {
      // forward and backward anti-parallel or parallel
      return forward.normalized;
    } else {
      Vector3 proj = Vector3.Project(forward.normalized, bisector);
      return (forward.normalized - proj).normalized;
    }
  }
}
